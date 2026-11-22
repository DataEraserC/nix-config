{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.desktop.hypridle;
in
{
  # Downstream variant of the idle management: option-tuned listeners with a
  # Noctalia lock and niri power-off. It coexists with the upstream
  # hypridle/default.nix module - hosts pick an implementation through
  # `modules.desktop.hypridle.implementation` (the upstream file runs when
  # "upstream" is selected, this one when "downstream" is).
  options.modules.desktop.hypridle.implementation = lib.mkOption {
    type = lib.types.enum [
      "upstream"
      "downstream"
    ];
    default = "upstream";
    description = "Which hypridle listener set to deploy.";
  };

  options.modules.desktop.hypridle.keyboardDevice = lib.mkOption {
    type = lib.types.str;
    default = "kbd_backlight";
    description = "Keyboard backlight device name used by brightnessctl (see `brightnessctl --list`).";
  };

  config = lib.mkIf (cfg.enable && cfg.implementation == "downstream") {
    # Hyprland/niri idle daemon. Declared in Nix (instead of a raw
    # hypridle.conf) so each host can tune the timeouts below.
    services.hypridle = {
      enable = true;

      settings = {
        general = {
          lock_cmd = "noctalia msg session lock";
          before_sleep_cmd = "noctalia msg session lock";
          # niri already owns org.freedesktop.ScreenSaver and feeds its
          # inhibitors into the compositor idle notifier, so hypridle must not
          # try to claim the interface (it would log "already providing...").
          ignore_dbus_inhibit = true;
        };

        listener = [
          {
            timeout = cfg.keyboardBacklightTimeout;
            # brightnessctl --list / -d <device>
            on-timeout = "brightnessctl --save --device=${cfg.keyboardDevice} set 0";
            on-resume = "brightnessctl --restore --device=${cfg.keyboardDevice}";
          }
          {
            timeout = cfg.screenOffTimeout;
            ignore_inhibit = true;
            # Some apps keep idle-inhibit active even when they are only sitting
            # on a page, which can prevent screen-off forever. Ignore those
            # inhibitors for screen-off, but skip while an MPRIS player reports
            # active playback.
            condition_cmd = "! playerctl -a status 2>/dev/null | grep -q '^Playing$'";
            condition_retry = 30;
            on-timeout = "niri msg action power-off-monitors";
            on-resume = "niri msg action power-on-monitors";
          }
          {
            timeout = cfg.lockTimeout;
            ignore_inhibit = true;
            # Skip while media is playing, same as screen-off above.
            condition_cmd = "! playerctl -a status 2>/dev/null | grep -q '^Playing$'";
            condition_retry = 30;
            on-timeout = "noctalia msg session lock";
          }
        ];
      };
    };
  };
}
