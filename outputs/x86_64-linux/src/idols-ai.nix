{
  # NOTE: the args not used in this file CAN NOT be removed!
  # because haumea pass argument lazily,
  # and these arguments are used in the functions like `mylib.nixosSystem`, `mylib.colmenaSystem`, etc.
  inputs,
  lib,
  myvars,
  mylib,
  system,
  genSpecialArgs,
  niri,
  ...
}@args:
let
  # 星野 アイ, Hoshino Ai
  name = "ai";
  base-modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/options.nix"
        "secrets/nixos_agenix.nix"
        "secrets/nixos_sopsnix.nix"
        "modules/nixos/desktop.nix"
        # host specific
        "hosts/idols-${name}"
        # nixos hardening
        # "hardening/profiles/default.nix"
        "hardening/nixpaks"
        "hardening/bwraps"
      ])
      ++ [
        {
          modules.desktop.fonts.enable = true;
          modules.desktop.wayland.enable = true;
          modules.secrets.desktop.enable = true;
          modules.secrets.preservation.enable = true;
          modules.desktop.gaming.enable = true;
          modules.desktop.appcast.enable = true;
          modules.desktop.dsh.enable = true;
          modules.vscode-server.enable = true;
        }
        inputs.daeuniverse.nixosModules.dae
        inputs.daeuniverse.nixosModules.daed
        inputs.chaotic.nixosModules.default
        {
          modules.outOfStoreSymlink = {
            enable = true;
            paths = {
              configPath = "/home/nixos/nix-config";
              wallpaperPath = "/home/nixos/Documents/code/wallpapers";
              passwordStorePath = "/home/nixos/nix-config/secrets/PasswordStore";
            };
          };
        }
      ];
    home-modules =
      map mylib.relativeToRoot [
        "home/hosts/linux/idols-${name}.nix"
      ]
      ++ [
        {
          modules.outOfStoreSymlink = {
            enable = true;
            paths = {
              configPath = "/home/nixos/nix-config";
              wallpaperPath = "/home/nixos/Documents/code/wallpapers";
              passwordStorePath = "/home/nixos/nix-config/secrets/PasswordStore";
            };
          };
          modules.desktop.gaming.enable = true;
        }
      ];
  };

  modules-niri = {
    nixos-modules = [
      {
        programs.niri.enable = true;
        modules.desktop.niri.enable = true;
      }
    ]
    ++ base-modules.nixos-modules;
    home-modules = [
      { modules.desktop.niri.enable = true; }
    ]
    ++ base-modules.home-modules;
  };

  modules-gnome-wayland = {
    nixos-modules = [
      {
        modules.desktop.fonts.enable = true;
        modules.desktop.wayland.enable = true;
        modules.secrets.desktop.enable = true;
        modules.secrets.preservation.enable = true;
        modules.desktop.gnome-wayland.enable = true;
      }
    ]
    ++ base-modules.nixos-modules;
    home-modules = [
      { modules.desktop.gnome-wayland.enable = true; }
    ]
    ++ base-modules.home-modules;
  };
  modules-kde-wayland = {
    nixos-modules = [
      {
        modules.desktop.fonts.enable = true;
        modules.desktop.wayland.enable = true;
        modules.secrets.desktop.enable = true;
        modules.secrets.preservation.enable = true;
        modules.desktop.kde-wayland.enable = true;
      }
    ]
    ++ base-modules.nixos-modules;
    home-modules = [
      { modules.desktop.kde-wayland.enable = true; }
    ]
    ++ base-modules.home-modules;
  };

in
{
  nixosConfigurations = {
    # with gnome-wayland window manager
    "${name}-gnome-wayland" = mylib.nixosSystem (modules-gnome-wayland // args);
    # with kde-wayland window manager
    "${name}-kde-wayland" = mylib.nixosSystem (modules-kde-wayland // args);
    "${name}-niri" = mylib.nixosSystem (modules-niri // args);
  };

  # generate iso image for hosts with desktop environment
  packages = {
    "${name}-gnome-wayland" =
      inputs.self.nixosConfigurations."${name}-gnome-wayland".config.system.build.images.iso;
    "${name}-kde-wayland" =
      inputs.self.nixosConfigurations."${name}-kde-wayland".config.system.build.images.iso;
    "${name}-niri" = inputs.self.nixosConfigurations."${name}-niri".config.system.build.images.iso;
  };
}
