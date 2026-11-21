# systemd-logind power-button / lid-switch policy.
#
# A standalone module instead of a shared desktop snippet: the previous global
# settings collided with host-specific overrides (12kingdoms-shoukei
# apple-silicon.nix sets suspend, the shared snippet set ignore) and broke the
# shoukei-logind eval test. Hosts opt in via `modules.logind.enable`; the
# default derives from the hostname so idols-ai keeps the old behavior while
# every other host falls back to the nixpkgs defaults / its own overrides.
{ config, lib, ... }:
let
  cfg = config.modules.logind;
in
{
  options.modules.logind = {
    hostName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "Hostname used to derive the default enable state.";
    };

    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.hostName == "ai";
      defaultText = lib.literalExpression ''cfg.hostName == "ai"'';
      description = "Whether to apply this host's logind power-button / lid-switch policy.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.logind.settings.Login = {
      KillUserProcesses = false;
      HandleLidSwitch = "ignore";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandlePowerKey = "ignore";
    };
  };
}
