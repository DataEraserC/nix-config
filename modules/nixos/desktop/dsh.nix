{
  pkgs,
  deepseek-harness,
  config,
  lib,
  ...
}:
let
  cfg = config.modules.desktop.dsh;
in
{
  imports = [ deepseek-harness.nixosModules.default ];

  options.modules.desktop.dsh = {
    enable = lib.mkEnableOption "DeepSeek Harness (dsh)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.dsh.dsh-desktop ];

    programs.dsh = {
      enable = true;
      profiles = {
        tui.bundles = [ pkgs.dsh.bundles.tui ];
        web.bundles = [ pkgs.dsh.bundles.web-app ];
      };
      defaultProfile = "nix-tui";
    };
  };
}
