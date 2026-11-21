{
  pkgs,
  appcast,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.modules.desktop.appcast;
in
{
  imports = [
    appcast.nixosModules.default
  ];

  options.modules.desktop = {
    appcast = {
      enable = mkEnableOption "cast an app's GUI into a native window on this desktop";
    };
  };

  config = mkIf cfg.enable {
    # appcast + embedded-webview transporter plugin, declaratively.
    programs.appcast = {
      enable = true;
      package = appcast.packages.${pkgs.system}.default;
      plugins = [ appcast.packages.${pkgs.system}.webview-plugin ];
    };
  };
}
