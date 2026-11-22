# Linyaps (openKylin's containerized app format) packaged for the desktop.
{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.linyaps;
in
{
  options.modules.linyaps = {
    enable = lib.mkEnableOption "Linyaps (linyaps) containerized app support";
  };

  config = lib.mkIf cfg.enable {
    services.linyaps.enable = true;
  };
}
