{
  pkgs,
  lib,
  config,
  ...
}:
{
  # unified entry of China education network mirrors(CERNET)
  # ref: https://help.mirrors.cernet.edu.cn/nix-channels/
  nix.settings.substituters = [ "https://mirrors.cernet.edu.cn/nix-channels/store" ];
  nix.package = pkgs.nix;
}
