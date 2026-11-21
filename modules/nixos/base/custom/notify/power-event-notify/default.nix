# ===============================================================================
#
# Notify on AC power loss/restore via ntfy(markdown), event-driven.
#
# The Linux kernel emits a `change` uevent for the power_supply Mains device
# whenever the AC adapter is plugged/unplugged. A udev rule matches those
# events and starts a one-shot systemd unit that publishes the notification, so
# there is zero polling cost and the message arrives within ~1s of the event.
#
# Notification metadata follows the repo-wide ntfy message spec:
#   title "<host> · power lost"/"<host> · power restored",
#   tags "warning"/"electric_plug", priority high/low.
#
# Architecture note: the script's logic lives in ./power-event-notify.sh
# as a plain shell file(no nix interpolation inside), all config-dependent values
# are injected into the systemd unit via `environment`.
#
# Secrets are sourced at runtime from ntfyTopicFile(default
# /etc/agenix/ntfy-topic.env, provides $NTFY_TOPIC). Publish failures are logged
# only, they never fail the service.
#
# Edge handling: the script keeps the last notified state under /run(tmpfs), so
# duplicate uevents for the same state are ignored, events that happen while
# suspended are delivered as change events on resume, and the state resets on
# every boot with no stale notifications.
#
# Fallback: if the platform's ACPI/legion driver does not emit Mains change
# events(check with `udevadm monitor --property` while unplugging), switch
# `trigger` to "timer" to poll every `interval` instead; the notify logic is
# shared and needs no code change.
#
# Check logs:
#   journalctl -u power-event-notify
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.power-event-notify;

  script = pkgs.writeShellScript "power-event-notify" (builtins.readFile ./power-event-notify.sh);

  # udev rule file shipped via services.udev.packages(composes cleanly with
  # other udev rule sources such as modules/nixos/desktop/peripherals.nix).
  # ACTION=="change" only: `add` events at boot would not be a real transition,
  # and in udev mode every change event is a genuine plug/unplug.
  udevRules = pkgs.writeTextFile {
    name = "power-event-notify-udev-rules";
    destination = "/lib/udev/rules.d/80-power-event-notify.rules";
    # udev rules are parsed per physical line: no backslash continuation, keep
    # the whole rule on one line.
    text = ''
      SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ACTION=="change", RUN+="${pkgs.systemd}/bin/systemctl start --no-block power-event-notify.service"
    '';
  };
in
{
  options.modules.power-event-notify = {
    enable = lib.mkEnableOption ''
      ntfy notifications when the AC power supply is lost/restored
    '';

    hostName = lib.mkOption {
      type = lib.types.str;
      description = ''
        Hostname shown in the notification message and the ntfy title.
        Set it explicitly from the importing host(keeps this module decoupled
        from other modules' configuration).
      '';
    };

    trigger = lib.mkOption {
      type = lib.types.enum [
        "udev"
        "timer"
      ];
      default = "udev";
      description = ''
        How the check is triggered:
        - "udev": react to kernel power_supply(Mains) uevents(no polling, ~1s
          response). Default, requires the platform to emit those events.
        - "timer": poll every `interval` as a fallback when the uevent is
          unreliable on the target hardware.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "1min";
      description = ''
        Poll interval, only used when `trigger` is "timer". Time between checks,
        as a systemd time span(see systemd.time(7)).
      '';
    };

    ntfyTopicFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/agenix/ntfy-topic.env";
      description = ''
        Environment file sourced at runtime to obtain the ntfy topic.
        Expected content: NTFY_TOPIC=<topic>. When the file is missing or the
        variable is empty, the notification is skipped with a log message.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.power-event-notify = {
      description = "Notify on AC power loss/restore via ntfy";
      # No network-online dependency on purpose: this unit is started on demand
      # by udev at runtime, and waiting on network-online could wedge the start
      # job while the machine is offline. Publishing is best-effort anyway.
      path = with pkgs; [
        bash
        coreutils
        gnugrep
        gnused
        curl
        ntfy-sh
      ];
      # all config-dependent values are injected as environment variables,
      # so that the shell script stays decoupled from nix evaluation.
      environment = {
        HOST_NAME = cfg.hostName;
        NTFY_TOPIC_FILE = toString cfg.ntfyTopicFile;
        SEED_IF_EMPTY = if cfg.trigger == "timer" then "1" else "0";
      };
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = script;
      };
    };

    services.udev.packages = lib.mkIf (cfg.trigger == "udev") [ udevRules ];

    # polling fallback trigger(instead of the udev rule above)
    systemd.timers.power-event-notify = lib.mkIf (cfg.trigger == "timer") {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "power-event-notify.service";
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.interval;
      };
    };
  };
}
