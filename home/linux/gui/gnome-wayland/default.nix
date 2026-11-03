{
  pkgs,
  config,
  lib,
  ...
}@args:
with lib;
let
  cfg = config.modules.desktop.gnome-wayland;
in
{
  imports = [
    ./options
  ];

  options.modules.desktop.gnome-wayland = {
    enable = mkEnableOption "gnome wayland window manager";
    rdpPrimaryMonitor = {
      enable = mkEnableOption "optional rdp-primary-monitor GNOME Shell extension (personal; default off; may break on GNOME upgrades)";
    };
  };

  config = mkIf cfg.enable (mkMerge (import ./values args));
}
