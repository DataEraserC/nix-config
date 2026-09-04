# ===============================================================================
#
# Auto power-off when the machine stays offline for a while.
#
# A systemd timer periodically probes a set of targets(ping). If none of them is
# reachable continuously for `gracePeriod`, the machine is powered off.
#
# This is intended for always-on machines that should not linger without a
# network(and thus without remote access), e.g. idols-ai.
#
# Safety:
#   - The offline timer only starts counting after the first probe failure, and
#     resets as soon as any target responds again.
#   - The "offline since" state lives under /run so it is cleared on every boot:
#     a boot into an offline network restarts the full grace period instead of
#     powering off immediately.
#   - No target is checked if `targets` is empty, so an unconfigured host never
#     powers off by accident.
#
# All knobs(`enable`, `targets`, `gracePeriod`, ...) are exposed as options so
# the behavior can be overridden per host.
#
# TEMPORARY RUNTIME OVERRIDES (no rebuild, reset on reboot):
#   The check script re-reads /run/offline-shutdown/override.env on every tick.
#   Use the `offline-shutdown` command(root) to tweak it live:
#     sudo offline-shutdown disable            # disable until next reboot
#     sudo offline-shutdown enable
#     sudo offline-shutdown grace 1h           # change grace until next reboot
#     sudo offline-shutdown reset              # drop override, back to nix defaults
#   Because the override lives under /run(tmpfs), every change reverts to the
#   nix-declared defaults after a reboot.
#
# Check timer:    systemctl list-timers offline-shutdown.timer
# Check logs:     journalctl -u offline-shutdown --since "1 hour ago"
# Manual test:    systemctl start offline-shutdown.service
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.offline-shutdown;

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
      throw "modules.offline-shutdown: invalid span '${span}', expected e.g. 30s/30m/30min/1h/1d"
    else
      n * mul.${if unit == null then "s" else unit};

  script = pkgs.writeShellScript "offline-shutdown-check" (
    builtins.readFile ../scripts/offline-shutdown-check.sh
  );

  # CLI for temporary runtime overrides(no rebuild). It only writes a file under
  # /run, so any change resets to the nix defaults on the next reboot.
  cli = pkgs.writeShellScriptBin "offline-shutdown" (
    builtins.readFile ../scripts/offline-shutdown-cli.sh
  );
in
{
  options.modules.offline-shutdown = {
    enable = lib.mkEnableOption ''
      auto power-off when the machine stays offline for `gracePeriod`
    '';

    targets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Hosts/IPs probed by ping to decide whether the machine is online.
        The machine is considered offline only when none of them responds.
        Empty(default) disables the check entirely.
      '';
    };

    gracePeriod = lib.mkOption {
      type = lib.types.str;
      default = "30min";
      example = "1h";
      description = ''
        How long the machine must stay offline(ping to every target failing)
        before it is powered off. Single-token span, supported units: s/m/min/h/d.
      '';
    };

    bootDelay = lib.mkOption {
      type = lib.types.str;
      default = "2min";
      example = "5min";
      description = ''
        How long after boot to wait before the first probe runs, so the network
        has a chance to come up.
      '';
    };

    checkInterval = lib.mkOption {
      type = lib.types.str;
      default = "1min";
      description = ''
        How often to probe the targets.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cli ];

    systemd.timers.offline-shutdown = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "offline-shutdown.service";
        OnBootSec = cfg.bootDelay;
        OnUnitActiveSec = cfg.checkInterval;
      };
    };

    systemd.services.offline-shutdown = {
      description = "Power off after the machine stays offline for ${cfg.gracePeriod}";
      path = with pkgs; [
        bash
        coreutils
        iputils
        systemd
      ];
      # config-dependent values are injected as environment variables so the
      # shell script stays decoupled from nix evaluation.
      environment = {
        TARGETS = lib.concatStringsSep " " cfg.targets;
        GRACE_SECONDS = toString (toSeconds cfg.gracePeriod);
      };
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = script;
      };
    };
  };
}
