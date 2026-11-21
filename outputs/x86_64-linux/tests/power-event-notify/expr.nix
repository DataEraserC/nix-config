{
  lib,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
in
{
  powerEventServiceDefined = cfg.systemd.services ? power-event-notify;
  powerEventUdevRulesInstalled = lib.elem "power-event-notify-udev-rules" (
    builtins.map (p: p.name) cfg.services.udev.packages
  );
  powerEventTriggeredByTimer = cfg.systemd.timers ? power-event-notify;
  heartbeatServiceDefined = cfg.systemd.services ? host-heartbeat;
}
