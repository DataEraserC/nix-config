# ===============================================================================
#
# WebMux - a terminal that keeps running in the browser, built to drive CLI
# agents (Claude Code, Codex, omp, ...) from another device:
# https://github.com/mzdluo123/webmux
#
# The package comes from the DataEraserC NUR
# (`nur-DataEraserC.packages.<system>.webmux`); this module owns the unit, the
# service account and the whole state layout, so no NUR module is involved.
#
# Runs as the LOGIN user on purpose, not as a dedicated account: WebMux starts
# every session as its own service user, so only the login user's HOME has the
# agent logins (`~/.claude`, `~/.codex`), the home-manager profile on PATH and
# the project trees a session is meant to work in. A dedicated account would
# expose a terminal that can do nothing. Consequence: this service is a remote
# shell as the login user - reach it over the VPN overlays only, and keep the
# token.
#
# State layout - stateDir = /var/lib/webmux (systemd StateDirectory):
#   /var/lib/webmux/config.toml     listen address, defaults, and the access
#                                   token unless `tokenFile` supplies it
#   /var/lib/webmux/webmux/         upstream state dir ($XDG_STATE_HOME/webmux):
#                                   launch-configs.json, repositories.json,
#                                   hybrid-sessions.json, run/webmux.sock
#
# config.toml is seeded ONCE by `webmux config init`, not written on every
# start: it holds the random access token that upstream generates on first
# start, so a declarative rewrite would rotate the token on every activation and
# invalidate every saved browser session. Only the listen address is forced on
# the command line (`--listen` beats the file), so moving the port in the port
# registry takes effect on the next restart. Everything else in that file -
# `default_cwd`, `allowed_origins`, `scrollback_bytes`, `[voice]`, ... - is
# yours to edit in place; a redeploy keeps it.
#
# The token - upstream reads it from config.toml or `serve --token`, there is no
# environment variable it honours on its own. Setting `tokenFile` takes it out of
# the state directory: the unit gets an EnvironmentFile (`WEBMUX_TOKEN=...`) and
# passes it as `--token`, so the secret stays in agenix and the seeded config is
# stripped of its random token. The token then shows up in the process command
# line (`/proc/<pid>/cmdline`, readable by every local user) - acceptable on a
# single-user host, and the only way to keep it out of a 0600 file the running
# user owns. Web edits to the token in the UI are ignored while `tokenFile` is
# set; rotate it by rotating the secret and restarting the unit.
#
# Reading the access token with `tokenFile` unset (the subcommand comes first;
# `XDG_STATE_HOME` is what the client uses to find the running instance, the unit
# sets it to stateDir):
#   sudo -u <user> env XDG_STATE_HOME=/var/lib/webmux /run/current-system/sw/bin/webmux \
#     status --config /var/lib/webmux/config.toml --json --reveal-token
# With `tokenFile` set it is the secret instead:
#   sudo cat /run/agenix/webmux.env
# `webmux status` then reports a `token` entry under `drift`: the running token
# comes from the environment while config.toml has none. That is expected, not a
# misconfiguration.
# Resetting the token (all browsers must log in again): delete the file the
# token came from and restart - `rm /var/lib/webmux/config.toml` in the first
# case, a rotated secret in the second.
#
# The repository panel shells out to `git`, so the unit's PATH carries git and
# ssh: systemd hands a unit the compiled-in default PATH (`/usr/bin`, ...), which
# on NixOS resolves to nothing, and home-manager's git is not in a system
# directory either. Without it the panel reports "Git 不可用: exec: git:
# executable file not found in $PATH" while sessions keep working.
#
# Binds to 0.0.0.0:<port> by default. The shared host firewall trusts only the
# LAN and the overlay interfaces, so the page is reachable from the tailnet /
# zerotier / easytier peers and not from the internet; the token is the only
# authentication, so keep `openFirewall` off unless a TLS reverse proxy with its
# own auth sits in front.
#
# No sandboxing beyond the default: sessions are arbitrary shells (agents call
# sudo, write /tmp, use /dev, ...), so ProtectHome / PrivateTmp / NoNewPrivileges
# cannot be enabled without breaking what the service is for.
#
# `Restart` restarts end every running session (upstream behaviour: sessions and
# scrollback live in memory), so a redeploy or `systemctl restart webmux` drops
# whatever an agent was doing - finish or detach it first.
#
# Check service status
#   systemctl status webmux
# Check logs
#   journalctl -u webmux --since "2 minutes ago"
{
  config,
  lib,
  pkgs,
  myvars,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.webmux;
  system = pkgs.stdenv.hostPlatform.system;

  inherit (cfg) stateDir;

  useStateDirectory = builtins.dirOf stateDir == "/var/lib";

  # Resolve the executable without `lib.getExe cfg.package` when the package is
  # unset, so a missing NUR build reports through the assertion instead of a type
  # error during evaluation.
  webmuxExe = if cfg.package != null then lib.getExe cfg.package else "${pkgs.coreutils}/bin/false";

  userInfo = config.users.users.${cfg.user} or { };
  home = userInfo.home or stateDir;
  shell = userInfo.shell or "${pkgs.bashInteractive}/bin/bash";

  listen = "${cfg.host}:${toString cfg.port}";
  configPath = "${stateDir}/config.toml";

  hasTokenFile = cfg.tokenFile != null;

  # Seed the config exactly once: `webmux config init` writes the upstream
  # template, creating the parent directory 0700 and the file 0600, and `-s`
  # (not `-e`) retries after a truncated leftover file.
  #
  # With `tokenFile` the token comes from the environment instead - the CLI flag
  # beats the file - so the `token` line is removed on every start: the seeded
  # one, and one an earlier deployment or the web UI wrote. That also cleans up a
  # state directory that already carried a token before `tokenFile` was set.
  seedConfig = pkgs.writeShellScript "webmux-config-init" ''
    set -eu
    if [ ! -s ${lib.escapeShellArg configPath} ]; then
      ${webmuxExe} config init \
        --config ${lib.escapeShellArg configPath} \
        --listen ${lib.escapeShellArg listen}
    fi
    ${lib.optionalString hasTokenFile ''
      ${pkgs.gnused}/bin/sed -i '/^[[:space:]]*token[[:space:]]*=/d' ${lib.escapeShellArg configPath}
    ''}
  '';
in
{
  options.modules.webmux = {
    enable = lib.mkEnableOption "WebMux browser terminal server";

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port WebMux serves HTTP/WebSocket on; the host that uses this module must set it (port registry myvars.networking.services.webmux.hosts.<machine>.port).";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      example = "127.0.0.1";
      description = ''
        Address WebMux binds to. The default listens on every interface and is
        reachable from the LAN and the VPN overlays the shared firewall trusts,
        authenticated by the access token alone; set 127.0.0.1 to keep the
        terminal on the host and reach it through an SSH tunnel instead.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/webmux";
      description = ''
        Writable directory holding `config.toml` (with the access token) and the
        upstream state directory. Directories directly below
        <filename>/var/lib</filename> are created by systemd; any other path is
        created by an activation script and granted to the service user.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = myvars.username;
      description = ''
        Account the unit and every terminal session run as. Defaults to the
        login user because sessions must inherit its HOME, agent logins and
        PATH; the account has to exist already and this module never creates
        one. Changing it after the first start needs the state directory handed
        over: `chown -R <user>:<group> /var/lib/webmux`.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = "Primary group of `user`; must already exist.";
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = nur-DataEraserC.packages.${system}.webmux or null;
      description = ''
        WebMux package. Defaults to the DataEraserC NUR build, which is the
        repository version when the NUR overlay is applied.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--log-file"
        "/var/lib/webmux/webmux.log"
      ];
      description = "Extra arguments appended to `webmux serve`, after the managed `--config`, `--listen` and `--token`.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/agenix/webmux.env";
      description = ''
        systemd EnvironmentFile holding `WEBMUX_TOKEN=<token>`; when set, the
        access token comes from there - `serve --token` - instead of
        `config.toml`, and the seeded config keeps no token at all.

        systemd reads the file before dropping privileges, so it can stay
        root-only (the agenix default), and the token never needs to be readable
        by the service user. Upstream has no token environment variable of its
        own: this module turns the file into the `--token` flag. The token is
        therefore visible in the process command line. Keep it to a host where
        every local user is trusted, or leave this unset and keep the 0600
        `config.toml`.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open `port` in the host firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "modules.webmux.package must be set when the service is enabled (the DataEraserC NUR is not providing `webmux`).";
      }
      {
        assertion = builtins.hasAttr cfg.user config.users.users;
        message = ''
          modules.webmux.user is set to "${cfg.user}", but that user is not defined.
          This module runs the terminal as an existing account on purpose (sessions
          need its HOME and agent logins); define users.users."${cfg.user}" or pick
          another user.
        '';
      }
      {
        assertion = builtins.hasAttr cfg.group config.users.groups;
        message = "modules.webmux.group is set to \"${cfg.group}\", but that group is not defined.";
      }
    ];

    systemd.services.webmux = {
      description = "WebMux persistent browser terminal server";
      documentation = [ "https://github.com/mzdluo123/webmux" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # Sessions inherit HOME, SHELL and the XDG state root, so they behave like
      # a login from the console; XDG_STATE_HOME keeps the upstream state
      # directory inside stateDir instead of the (wiped) home.
      environment = {
        HOME = home;
        SHELL = shell;
        XDG_STATE_HOME = stateDir;
      };

      # Prepended to the minimal service PATH NixOS builds by default (coreutils,
      # findutils, grep, sed, systemd). Without it the repository panel reports
      # "Git 不可用: exec: git: executable file not found in $PATH", because the
      # login user's git comes from home-manager and never reaches a unit; ssh is
      # here for ssh remotes.
      path = [
        pkgs.git
        pkgs.openssh
      ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = home;
        ExecStartPre = "${seedConfig}";
        ExecStart = lib.concatStringsSep " " (
          map lib.escapeShellArg [
            webmuxExe
            "serve"
            "--config"
            configPath
            # Always passed: the seeded config keeps the port it was created
            # with, so a registry change would otherwise never take effect.
            "--listen"
            listen
          ]
          # Expanded by systemd from the EnvironmentFile, so it must stay
          # unescaped; `$` is not a Nix interpolation here. Kept before
          # extraArgs so a host can still pin its own token by hand.
          ++ lib.optional hasTokenFile "--token \${WEBMUX_TOKEN}"
          ++ map lib.escapeShellArg cfg.extraArgs
        );
        Restart = "on-failure";
        RestartSec = 5;
      }
      // lib.optionalAttrs hasTokenFile {
        EnvironmentFile = cfg.tokenFile;
        # A missing agenix secret should fail loudly instead of starting a
        # second instance with an empty token.
        AssertPathExists = [ cfg.tokenFile ];
      }
      // lib.optionalAttrs useStateDirectory {
        StateDirectory = [ (builtins.baseNameOf stateDir) ];
        StateDirectoryMode = "0700";
      }
      // lib.optionalAttrs (!useStateDirectory) {
        ReadWritePaths = [ stateDir ];
      };
    };

    system.activationScripts.webmux = lib.mkIf (!useStateDirectory) (
      lib.stringAfter [ "users" ] ''
        install -d -m 0700 -o ${cfg.user} -g ${cfg.group} ${lib.escapeShellArg stateDir}
      ''
    );

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
