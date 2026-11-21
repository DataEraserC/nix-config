# Optional GNOME Shell extension for RDP `extend` mode.
#
# Personal, best-effort extension: it changes Mutter's display configuration
# through the `org.gnome.Mutter.DisplayConfig` D-Bus interface and can break
# when GNOME Shell changes. It is off by default and only meaningful while
# GNOME Remote Desktop runs in `extend` mode.
{
  config,
  lib,
  nur-DataEraserC,
  pkgs,
  ...
}:
let
  cfg = config.modules.desktop.gnome-wayland;
in
{
  home.packages =
    lib.optional cfg.rdpPrimaryMonitor.enable
      nur-DataEraserC.packages.${pkgs.system}.rdp-primary-monitor;

  dconf.settings."org/gnome/shell".enabled-extensions =
    lib.optional cfg.rdpPrimaryMonitor.enable "rdp-primary-monitor@michal-b-bozek.github.io";
}
