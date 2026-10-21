# ===============================================================================
#
# Agent accounts - run each AI agent / IDE under bubblewrap with a per-account
# state directory.
#
# All six apps keep their state in a path hardcoded under $HOME, and no single
# upstream switch covers them; the exact paths are listed in agent-acct.sh.
# Mounting a per-account directory over each of those paths with bubblewrap
# redirects all of them the same way, without patching or wrapping any package.
#
# The sandbox remaps paths; it is not a confinement boundary. $HOME stays
# writable at its real path, so absolute work-directory paths, git config and
# build caches behave exactly as before. Only those state paths are replaced,
# and the account store itself is hidden from the app (tmpfs).
#
# Usage
#   agent-acct <app> <account> [args...]
#   agent-acct codebuddy work
#   agent-acct trae-cn 1
#
# An account always starts empty. Nothing is copied out of the app's existing
# state under $HOME, so a plain `trae-cn` keeps its own login untouched and an
# account never inherits it. Configuring `desktopAccounts` gives each account a
# launcher entry (`Trae CN 1`, `Trae CN 2`, ...).
# ===============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.agent-accounts;

  # bubblewrap and coreutils are the only inputs this launcher takes from nix;
  # the logic itself lives in agent-acct.sh, next to this file.
  agent-acct = pkgs.writeShellApplication {
    name = "agent-acct";
    runtimeInputs = [
      pkgs.bubblewrap
      pkgs.coreutils
    ];
    text = builtins.readFile ./agent-acct.sh;
  };
  # Launcher metadata for the GUI apps. Names, icons and window classes match
  # the .desktop files the packages ship, so an account window is recognised by
  # the same icon as the app.
  guiApps = {
    workbuddy = {
      label = "WorkBuddy";
      icon = "workbuddy";
      wmclass = "workbuddy";
    };
    lobsterai = {
      label = "LobsterAI";
      icon = "lobsterai";
      wmclass = "LobsterAI";
    };
    trae-cn = {
      label = "Trae CN";
      icon = "trae-cn";
      wmclass = "Trae CN";
    };
    trae = {
      label = "Trae";
      icon = "trae";
      wmclass = "Trae";
    };
  };

  # A number means that many accounts, named "1".."N"; a list names them
  # explicitly, for accounts that are not just numbered.
  accountNames = value: if builtins.isInt value then map toString (lib.range 1 value) else value;

  mkLauncher =
    app: account:
    let
      meta = guiApps.${app};
    in
    pkgs.makeDesktopItem {
      name = "agent-acct-${app}-${account}";
      desktopName = "${meta.label} ${account}";
      genericName = meta.label;
      comment = "${meta.label}, account ${account}, with its own state directory";
      icon = meta.icon;
      exec = "${agent-acct}/bin/agent-acct ${app} ${account} %F";
      categories = [ "Development" ];
      startupWMClass = meta.wmclass;
      startupNotify = true;
    };
in
{
  options.modules.agent-accounts = {
    enable = lib.mkEnableOption ''
      the `agent-acct` launcher that runs the AI agents and IDEs above under
      bubblewrap with one state directory per account
    '';

    desktopAccounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.ints.positive
          (lib.types.listOf lib.types.str)
        ]
      );
      default = { };
      example = {
        workbuddy = 6;
        lobsterai = 2;
        trae-cn = [
          "work"
          "home"
        ];
      };
      description = ''
        Accounts to create a desktop launcher for, keyed by app. A number means
        that many accounts, named "1".."N"; a list names them explicitly. Each
        account gets one entry labelled "<app> <account>" that starts the app
        through `agent-acct` in its own state directory. Only the GUI apps are
        accepted: workbuddy, lobsterai, trae-cn, trae.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (app: builtins.hasAttr app guiApps) (builtins.attrNames cfg.desktopAccounts);
        message = "modules.agent-accounts.desktopAccounts: only the GUI apps workbuddy, lobsterai, trae-cn and trae can have a launcher";
      }
    ];

    environment.systemPackages = [
      agent-acct
    ]
    ++ lib.concatLists (
      lib.mapAttrsToList (app: value: map (mkLauncher app) (accountNames value)) cfg.desktopAccounts
    );
  };
}
