# ===============================================================================
#
# Agent accounts - run each AI agent / IDE with one state directory per account.
#
# The mechanism lives in modules/multi-instance: every app below keeps its state
# in a path hardcoded under $HOME, and no single upstream switch covers them, so
# each account gets a directory bind-mounted over each path. Nothing here
# patches or wraps a package.
#
# Usage
#   multi-instance <app> <account> [args...]
#   multi-instance codebuddy work
#   multi-instance trae-cn 1
#
# An account always starts empty. Nothing is copied out of the app's existing
# state under $HOME, so a plain `trae-cn` keeps its own login untouched and an
# account never inherits it. Configuring `desktopAccounts` gives each account a
# launcher entry (`Trae CN 1`, `Trae CN 2`, ...).
# ===============================================================================
{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.agent-accounts;

  # The one table: where each app keeps its state, which of those paths survive a
  # tmpfs root, and how an account window is recognised by the desktop. An
  # account is added by changing `desktopAccounts`, not this table.
  apps = {
    codebuddy = {
      paths = [
        ".codebuddy"
        ".local/share/CodeBuddyExtension"
      ];
      persist = [
        {
          directory = ".codebuddy";
          mode = "0700";
        }
        {
          directory = ".local/share/CodeBuddyExtension";
          mode = "0700";
        }
      ];
    };

    # Its launcher exports these paths unconditionally.
    codearts = {
      paths = [ ".codeartsdoer" ];
      persist = [
        {
          directory = ".codeartsdoer";
          mode = "0700";
        }
      ];
    };

    # The shared Tencent auth (codebuddy + workbuddy) is built from os.homedir(),
    # so no environment variable reaches it; mounting over each path redirects
    # all of them the same way. ~/.sheetagent holds logs only and ~/WorkBuddy is
    # an empty scaffold, so neither is preserved.
    workbuddy = {
      paths = [
        ".workbuddy"
        ".sheetagent"
        "WorkBuddy"
        ".local/share/CodeBuddyExtension"
      ];
      persist = [
        {
          directory = ".workbuddy";
          mode = "0700";
        }
        {
          directory = ".local/share/CodeBuddyExtension";
          mode = "0700";
        }
      ];
      desktop = {
        label = "WorkBuddy";
        icon = "workbuddy";
        wmclass = "workbuddy";
      };
    };

    # It overwrites --user-data-dir, so ~/.config/LobsterAI is the only profile
    # path; ~/lobsterai is the default working directory it creates at startup.
    lobsterai = {
      paths = [
        ".config/LobsterAI"
        "lobsterai"
      ];
      persist = [
        {
          directory = ".config/LobsterAI";
          mode = "0700";
        }
        "lobsterai"
      ];
      desktop = {
        label = "LobsterAI";
        icon = "lobsterai";
        wmclass = "LobsterAI";
      };
    };

    # Its single-instance lock is named after the user data directory, so two
    # accounts would share one window without `userDataDir`.
    trae-cn = {
      paths = [
        ".trae-cn"
        ".config/Trae CN"
      ];
      userDataDir = ".config/Trae CN";
      persist = [
        ".trae-cn"
        {
          directory = ".config/Trae CN";
          mode = "0700";
        }
      ];
      desktop = {
        label = "Trae CN";
        icon = "trae-cn";
        wmclass = "Trae CN";
      };
    };

    trae = {
      paths = [
        ".trae"
        ".config/Trae"
      ];
      userDataDir = ".config/Trae";
      persist = [
        ".trae"
        {
          directory = ".config/Trae";
          mode = "0700";
        }
      ];
      desktop = {
        label = "Trae";
        icon = "trae";
        wmclass = "Trae";
      };
    };
  };
in
{
  options.modules.agent-accounts = {
    enable = lib.mkEnableOption ''
      the `multi-instance` launcher that runs the AI agents and IDEs above under
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
        through `multi-instance` in its own state directory. Only the GUI apps
        have a launcher: workbuddy, lobsterai, trae-cn, trae.
      '';
    };
  };

  # Declared whether or not the launcher is enabled: the paths are facts about
  # the apps, and their logins must survive a host that stops enabling this
  # module.
  config = {
    modules.multi-instance.apps = apps;
    modules.multi-instance.enable = cfg.enable;
    modules.multi-instance.instances = cfg.desktopAccounts;
  };
}
