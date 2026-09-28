# ===============================================================================
#
# Auto power-off when the machine stays in a shutdown-worthy state for a while.
#
# A systemd timer periodically runs a list of *condition* executables
# (`conditions`). Each executable exits 0 to mean "this check is OK"; any
# non-zero exit marks the machine shutdown-worthy for that check. How the list
# is combined is controlled by `mode`:
#   all -> every check must pass to keep the machine on(default)
#   any -> at least one passing check keeps the machine on
# Once the machine stays shutdown-worthy for `gracePeriod`, it is powered off.
#
# Conditions can be any executable: a ping wrapper, a service health probe, a
# load/temperature check, ... Build one from a shell script with
# `pkgs.writeShellScript` and point `command` at it.
#
# `targets` is legacy convenience sugar: it expands to one ping condition per
# host/IP and forces mode `any`(one reachable target keeps the machine on),
# preserving the original "auto power-off when offline" behavior.
#
# Safety:
#   - The countdown only starts after the first failed condition run, and
#     resets as soon as the conditions are OK again.
#   - The "failing since" state lives under /run so it is cleared on every
#     boot: a boot into failing conditions restarts the full grace period
#     instead of powering off immediately.
#   - No check runs if neither `conditions` nor `targets` is set, so an
#     unconfigured host never powers off by accident.
#
# All knobs(`enable`, `conditions`, `mode`, `targets`, `gracePeriod`, ...) are
# exposed as options so the behavior can be overridden per host.
#
# TEMPORARY RUNTIME OVERRIDES (no rebuild, reset on reboot):
#   The check script re-reads /run/auto-shutdown/override.env on every tick.
#   Use the `auto-shutdown` command(root) to tweak it live:
#     sudo auto-shutdown disable            # disable until next reboot
#     sudo auto-shutdown enable
#     sudo auto-shutdown grace 1h           # change grace until next reboot
#     sudo auto-shutdown reset              # drop override, back to nix defaults
#   Because the override lives under /run(tmpfs), every change reverts to the
#   nix-declared defaults after a reboot.
#
# Check timer:    systemctl list-timers auto-shutdown.timer
# Check logs:     journalctl -u auto-shutdown --since "1 hour ago"
# Manual test:    systemctl start auto-shutdown.service
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.auto-shutdown;

  # Parse a single-token systemd-style span("30min", "1h", "90s" ...) into
  # seconds. Kept intentionally simple; supported units: s/m/min/h/d.
  toSeconds =
    span:
    let
      m = builtins.match "([0-9]+)(min|[smhd])?" span;
      n = builtins.fromJSON (builtins.elemAt m 0);
      unit = builtins.elemAt m 1;
      mul = {
        s = 1;
        m = 60;
        min = 60;
        h = 3600;
        d = 86400;
      };
    in
    if m == null then
      throw "modules.auto-shutdown: invalid span '${span}', expected e.g. 30s/30m/30min/1h/1d"
    else
      n * mul.${if unit == null then "s" else unit};

  # Legacy sugar: turn `targets` into one ping condition per host/IP.
  targetCondition = target: {
    command = pkgs.writeShellScript "auto-shutdown-ping" ''
      exec ping -c 1 -W 2 ${target}
    '';
    name = "ping ${target}";
  };

  # Explicit `conditions` take precedence over the `targets` sugar.
  conditions = if cfg.conditions != [ ] then cfg.conditions else map targetCondition cfg.targets;

  # Human-readable labels for logs; fall back to the command path.
  conditionNames = map (c: if c.name == "" then toString c.command else c.name) conditions;

  # `targets` implies mode "any"(one reachable target = online), matching the
  # original offline-shutdown behavior; `conditions` follow the declared mode.
  mode = if cfg.conditions != [ ] then cfg.mode else "any";

  checkScript = pkgs.writeShellScript "auto-shutdown-check" (
    builtins.readFile ./auto-shutdown-check.sh
  );

  # CLI for temporary runtime overrides(no rebuild). It only writes a file under
  # /run, so any change resets to the nix defaults on the next reboot.
  cli = pkgs.writeShellScriptBin "auto-shutdown" (builtins.readFile ./auto-shutdown-cli.sh);
in
{
  options.modules.auto-shutdown = {
    enable = lib.mkEnableOption ''
      auto power-off when a shutdown-worthy state(e.g. offline) lasts for
      `gracePeriod`
    '';

    conditions = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            command = lib.mkOption {
              type = lib.types.path;
              description = ''
                Path to an executable run on every tick. Exit 0 means this check
                is OK; any non-zero exit marks the machine shutdown-worthy. Build
                one from a shell script with `pkgs.writeShellScript`.
              '';
            };
            name = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = ''
                Label used in logs(whitespace is replaced with `_`). Defaults to
                the command path.
              '';
            };
          };
        }
      );
      default = [ ];
      description = ''
        Executables that decide whether the machine should stay powered on,
        combined per `mode`. Empty(default, with `targets` also empty) disables
        the check entirely.
      '';
    };

    mode = lib.mkOption {
      type = lib.types.enum [
        "all"
        "any"
      ];
      default = "all";
      description = ''
        How `conditions` are combined. `all`: every check must pass to keep the
        machine on(any single failure is shutdown-worthy). `any`: at least one
        passing check keeps it on. Ignored while the `targets` sugar is used
        (which forces `any`).
      '';
    };

    targets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Legacy convenience sugar: hosts/IPs probed by ping, expanded into ping
        `conditions` with mode `any`. Ignored when `conditions` is set.
      '';
    };

    gracePeriod = lib.mkOption {
      type = lib.types.str;
      default = "30min";
      example = "1h";
      description = ''
        How long the machine must stay in a shutdown-worthy state before it is
        powered off. Single-token span, supported units: s/m/min/h/d.
      '';
    };

    bootDelay = lib.mkOption {
      type = lib.types.str;
      default = "2min";
      example = "5min";
      description = ''
        How long after boot to wait before the first check runs, so the network
        has a chance to come up.
      '';
    };

    checkInterval = lib.mkOption {
      type = lib.types.str;
      default = "1min";
      description = ''
        How often to run the condition checks.
      '';
    };

    verbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Log every condition's result and the overall verdict on each tick to the
        journal(`journalctl -u auto-shutdown`). Useful to see which check keeps
        the machine on. When off, only state transitions and failures are logged.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # `conditions` silently wins over `targets`; make the shadowing visible.
    warnings = lib.optional (cfg.conditions != [ ] && cfg.targets != [ ]) ''
      modules.auto-shutdown: both `conditions` and `targets` are set; the
      `targets` list is ignored in favor of `conditions`.
    '';

    environment.systemPackages = [ cli ];

    systemd.timers.auto-shutdown = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "auto-shutdown.service";
        OnBootSec = cfg.bootDelay;
        OnUnitActiveSec = cfg.checkInterval;
      };
    };

    systemd.services.auto-shutdown = {
      description = "Power off after a shutdown-worthy state lasts ${cfg.gracePeriod}";
      path = with pkgs; [
        bash
        coreutils
        iputils
        systemd
      ];
      # config-dependent values are injected as environment variables so the
      # shell scripts stay decoupled from nix evaluation.
      environment = {
        CONDITIONS = lib.concatStringsSep " " (map (c: c.command) conditions);
        CONDITION_NAMES = lib.concatStringsSep " " (
          map (n: lib.replaceStrings [ " " ] [ "_" ] n) conditionNames
        );
        MODE = mode;
        GRACE_SECONDS = toString (toSeconds cfg.gracePeriod);
        VERBOSE = if cfg.verbose then "1" else "0";
      };
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = checkScript;
      };
    };
  };
}
