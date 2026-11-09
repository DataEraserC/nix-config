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
#   /var/lib/webmux/config.toml     listen address, access token, defaults
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
# The token lives in config.toml (0600, owned by the service user): upstream
# reads it from that file or from `serve --token` and honours no environment
# variable of its own. A flag would put it in the process command line, which
# every local user can read through /proc, so the file is the safer home even
# though the service user can read it - it can run shells as that user anyway.
#
# Reading the access token (the subcommand comes first; `XDG_STATE_HOME` is what
# the client uses to find the running instance, the unit sets it to stateDir):
#   sudo -u <user> env XDG_STATE_HOME=/var/lib/webmux /run/current-system/sw/bin/webmux \
#     status --config /var/lib/webmux/config.toml --json --reveal-token
# Resetting the token (all browsers must log in again):
#   sudo rm /var/lib/webmux/config.toml && sudo systemctl restart webmux
#
# The repository panel shells out to `git`, so the unit's PATH carries git and
# ssh: systemd hands a unit the compiled-in default PATH (`/usr/bin`, ...), which
# on NixOS resolves to nothing, and home-manager's git is not in a system
# directory either. Without it the panel reports "Git 不可用: exec: git:
# executable file not found in $PATH" while sessions keep working.
#
# `SHELL` must be an executable file, not a package: WebMux uses `$SHELL` as the
# command of its "Shell" launch preset (`$SHELL -l -i`) and as the shell agent
# presets start through. See the `shell` binding below for the conversion.
#
# Those presets are seeded into `webmux/launch-configs.json` only while that file
# does not exist yet; an existing one is never rewritten, so a state directory
# created before a `SHELL` fix keeps the old (broken) command. Delete that file -
# it also drops user-made launch configs - or edit the "Shell" preset in the UI:
#   sudo rm /var/lib/webmux/webmux/launch-configs.json && sudo systemctl restart webmux
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
  utils,
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

  # `users.users.<name>.shell` holds a shell *package* (`bashInteractive` with
  # `shellPath = "/bin/bash"`) unless a host pinned a plain path, so it must not
  # be interpolated as is: that yields the store directory, and exec'ing a
  # directory fails with EACCES. WebMux takes `$SHELL` verbatim as the "Shell"
  # launch preset (`$SHELL -l -i`), which surfaced as "fork/exec
  # /nix/store/...-bash-interactive-5.3p15: permission denied". `utils.toShellPath`
  # is what NixOS itself writes into /etc/passwd - `/run/current-system/sw/bin/bash`
  # for a package - and passes a plain path through unchanged.
  shellOption = userInfo.shell or null;
  shell =
    if shellOption == null then "${pkgs.bashInteractive}/bin/bash" else utils.toShellPath shellOption;

  listen = "${cfg.host}:${toString cfg.port}";
  configPath = "${stateDir}/config.toml";

  # Seed the token-bearing config exactly once: `webmux config init` writes the
  # upstream template with a random token, creating the parent directory 0700
  # and the file 0600, and `-s` (not `-e`) retries after a truncated leftover.
  seedConfig = pkgs.writeShellScript "webmux-config-init" ''
    set -eu
    if [ -s ${lib.escapeShellArg configPath} ]; then
      exit 0
    fi
    exec ${webmuxExe} config init \
      --config ${lib.escapeShellArg configPath} \
      --listen ${lib.escapeShellArg listen}
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

    acpAgents = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            kind = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Protocol family; only \"acp\", which is also the default.";
            };
            title = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Display name in the session switcher; empty uses the executable name.";
            };
            icon = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Launch-config icon key; empty uses \"terminal\".";
            };
            acpArg = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Argument that starts the agent's ACP server (`--acp`, `acp`, ...); empty means `acp`.";
            };
            resumeFlag = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Flag that reopens a session in the terminal UI (`--resume`), passed the session ID.";
            };
            identity = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "How a terminal process is matched to an agent session; only \"none\" (fall back to session/list), which is also the default.";
            };
          };
        }
      );
      default = { };
      example = lib.literalExpression ''
        {
          codebuddy = {
            title = "CodeBuddy";
            acpArg = "--acp";
            resumeFlag = "--resume";
          };
        }
      '';
      description = ''
        Agents this build has no adapter for, keyed by executable base name. Only
        `package` = `webmux-acp` (the NUR build carrying the
        `WEBMUX_ACP_AGENTS` extension) can use them; the plain package ignores
        the variable and these agents keep their terminal-only behaviour.

        Upstream identifies an agent by the command name only, so a key must be
        the exact base name a launch config execs (`codebuddy`, not a wrapper
        path), and the agent has to answer ACP `initialize` itself. Capabilities
        that the handshake cannot report - `session/list` above all - come from
        the CLI or from a proxy such as `codebuddy-acp`; this module only
        declares the launch facts.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--log-file"
        "/var/lib/webmux/webmux.log"
      ];
      description = "Extra arguments appended to `webmux serve`, after the managed `--config` and `--listen`.";
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
      #
      # `WEBMUX_ACP_AGENTS` is read once at start by the `webmux-acp` build,
      # which rebuilds its agent registry from the JSON in this variable; the
      # plain package never looks at it. Empty fields are dropped so a declared
      # agent carries only the facts it needs, and the variable stays unset when
      # nothing is declared, which leaves the built-in registry untouched.
      environment = {
        HOME = home;
        SHELL = shell;
        XDG_STATE_HOME = stateDir;
      }
      // lib.optionalAttrs (cfg.acpAgents != { }) {
        WEBMUX_ACP_AGENTS = builtins.toJSON (
          lib.mapAttrs (_: spec: lib.filterAttrs (_: value: value != "") spec) cfg.acpAgents
        );
      };

      # A session must find what a console login finds. Only the "Shell" preset
      # runs a login shell that sources /etc/profile; everything a launch config
      # exec's directly - an agent preset, or a custom entry like
      # `multi-instance codebuddy 1` - inherits this unit's PATH alone, and the
      # NixOS service default is just coreutils/findutils/grep/sed/systemd.
      # git and ssh cover the repository panel (the login user's git comes from
      # home-manager and never reaches a unit); `environment.profiles` - the
      # same list set-environment turns into a login's $PATH - adds the system
      # profile and the user's own profiles, with its $HOME/$USER/
      # ${XDG_STATE_HOME} placeholders expanded for this unit's user, plus the
      # setuid wrappers.
      path = [
        pkgs.git
        pkgs.openssh
      ]
      ++ map (
        profile:
        lib.replaceStrings
          [
            "$HOME"
            "$USER"
            "\${XDG_STATE_HOME}"
          ]
          [
            home
            cfg.user
            "${home}/.local/state"
          ]
          profile
      ) config.environment.profiles
      ++ [ "/run/wrappers" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = home;
        ExecStartPre = "${seedConfig}";
        ExecStart = lib.escapeShellArgs (
          [
            webmuxExe
            "serve"
            "--config"
            configPath
            # Always passed: the seeded config keeps the port it was created
            # with, so a registry change would otherwise never take effect.
            "--listen"
            listen
          ]
          ++ cfg.extraArgs
        );
        Restart = "on-failure";
        RestartSec = 5;
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
