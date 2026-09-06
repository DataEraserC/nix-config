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
  ...
}@args:
let
  # y9000p2025
  name = "work";
  wsl-modules = {
    nixos-modules = [
      inputs.nixos-wsl.nixosModules.default
      inputs.vscode-remote-workaround.nixosModules.default
    ];
  };
  base-modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/options.nix"
        "secrets/nixos_agenix.nix"
        "secrets/nixos_sopsnix.nix"
        "modules/nixos/wsl/wsl_without_gpu.nix"
        # host specific
        "hosts/wsl-${name}"
        # nixos hardening
        # "hardening/profiles/default.nix"
        "hardening/nixpaks"
        "hardening/bwraps"
      ])
      ++ [
        {
          modules.secrets.desktop.enable = true;
          modules.secrets.preservation.enable = true;
          modules.vscode-server.enable = true;
        }
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
        # common
        "home/linux/wsl"
        # host specific
        "home/hosts/linux/wsl-${name}.nix"
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
        }
      ];
  };

  modules = {
    nixos-modules = [
      {
        modules.desktop.fonts.enable = true;
        # modules.desktop.wayland.enable = true;
        modules.secrets.desktop.enable = true;
        modules.secrets.preservation.enable = true;
        modules.desktop.appcast.enable = true;
        # modules.desktop.niri.enable = true;
      }
    ]
    ++ base-modules.nixos-modules
    ++ wsl-modules.nixos-modules;
    home-modules = [
      # { modules.desktop.niri.enable = true; }
    ]
    ++ base-modules.home-modules;
  };
in
{
  nixosConfigurations = {
    # host with hyprland compositor
    "wsl-${name}" = mylib.nixosSystem (modules // args);
  };

  # generate iso image for hosts with desktop environment
  packages = {
    "wsl-${name}" = inputs.self.nixosConfigurations."wsl-${name}".config.system.build.images.iso;
  };
}
