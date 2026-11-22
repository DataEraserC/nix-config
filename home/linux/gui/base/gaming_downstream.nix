# Downstream gaming packages, kept in a separate file so the upstream
# home/linux/gui/base/gaming.nix stays byte-identical. Gated on the same
# downstream flag the NixOS-side gaming-stack module uses (the option is
# defined in both module trees).
{
  config,
  pkgs,
  suyu,
  lib,
  ...
}:
with lib;
let
  cfg = config.modules.gaming-stack;
in
{
  options.modules.gaming-stack = {
    enable = mkEnableOption "the downstream gaming stack (home side)";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # https://github.com/flightlessmango/MangoHud
      # a simple overlay program for monitoring FPS, temperature, CPU and GPU load, and more.
      # Upstream's home gaming.nix also ships it, but that module is gated on
      # modules.desktop.gaming.enable (false here), so this file provides it.
      mangohud

      # Script to install various redistributable runtime libraries in Wine.
      winetricks
      # https://github.com/Open-Wine-Components/umu-launcher
      # a unified launcher for Windows games on Linux
      umu-launcher

      # Sed-like editor for binary files
      # required by some games to fix problems
      bbe

      # a GUI game launcher for Steam/GoG/Epic
      bottles

      # Wine related
      protonup-qt
      wineWow64Packages.waylandFull

      # Switch related
      suyu.packages.${pkgs.system}.suyu # Switch games
      ryubing # Switch games

      # Steam related
      steamcmd # steam command line

      # Ons related
      onscripter

      # Heroic Games Launcher - primarily for Epic Games & GOG
      # https://heroicgameslauncher.com/
      (heroic.override {
        extraPkgs = _pkgs: [
          pkgs.gamescope
        ];
      })
    ];
  };
}
