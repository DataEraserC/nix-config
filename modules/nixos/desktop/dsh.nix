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
        tui.bundles = [
          pkgs.dsh.bundles.tui
          pkgs.dsh.bundles.modsearch
          # pkgs.dsh.bundles.turn-rewind
          pkgs.dsh.bundles.cpa
          pkgs.dsh.bundles.remote
          # pkgs.dsh.bundles.message-edit
          pkgs.dsh.bundles.agent-teams
          pkgs.dsh.bundles.ads
          pkgs.dsh.bundles.navbar
        ];
        web.bundles = [
          pkgs.dsh.bundles.web-app
          pkgs.dsh.bundles.modsearch
          # pkgs.dsh.bundles.turn-rewind
          pkgs.dsh.bundles.web-ui
          pkgs.dsh.bundles.cpa
          pkgs.dsh.bundles.remote
          # pkgs.dsh.bundles.message-edit
          pkgs.dsh.bundles.agent-teams
          # pkgs.dsh.bundles.ads
          pkgs.dsh.bundles.navbar
        ];
      };
      defaultProfile = config.programs.dsh.profiles.tui.materializedName;
    };
  };
}
