{ config, mylib, ... }:
let
  hostName = "shoukei"; # Define your hostname.
  mkSymlink = mylib.mklinkRelativeToRoot;
in
{
  imports = [
    ../../linux/gui.nix
    ./12kingdoms-shoukei/wluma.nix
  ];

  programs.ssh.settings."github.com".IdentityFile = "${config.home.homeDirectory}/.ssh/${hostName}";

  modules.desktop.gaming.enable = false;
  modules.desktop.niri.enable = true;

  xdg.configFile."niri/niri-hardware.kdl".source =
    mkSymlink config "hosts/12kingdoms-shoukei/niri-hardware.kdl";
}
