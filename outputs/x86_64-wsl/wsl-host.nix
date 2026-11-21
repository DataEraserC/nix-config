# Shared generator for the WSL hosts. The two hosts differ only in their name
# and in whether they mount the GPU stack; everything else is identical, so it
# lives here instead of being copy-pasted into each src/ file.
#
# src/<host>.nix files are haumea leaves (one host per file); this generator
# sits outside src/ so haumea does not pick it up as a host.
{
  inputs,
  lib,
  myvars,
  mylib,
  system,
  genSpecialArgs,
  ...
}@args:
{
  # Host name without the `wsl-` prefix, e.g. `work` for `wsl-work`.
  name,
  # `wsl_with_gpu.nix` mounts the Windows GPU stack for CUDA;
  # `wsl_without_gpu.nix` skips it.
  gpuModule,
}:
let
  hostName = "wsl-${name}";
in
{
  nixosConfigurations.${hostName} = mylib.nixosSystem (
    {
      nixos-modules =
        (map mylib.relativeToRoot [
          # WSL platform support
          "modules/nixos/wsl/${gpuModule}"
          # host specific
          "hosts/${hostName}"
          # secrets
          "secrets/options.nix"
          "secrets/nixos_agenix.nix"
          "secrets/nixos_sopsnix.nix"
          # nixos hardening
          "hardening/nixpaks"
          "hardening/bwraps"
        ])
        ++ [
          inputs.nixos-wsl.nixosModules.default
          inputs.vscode-remote-workaround.nixosModules.default
          {
            modules.secrets.desktop.enable = true;
            modules.secrets.preservation.enable = true;
            modules.vscode-server.enable = true;

            # Host variant flags. `desktop.fonts` and `appcast` come from the
            # shared module files wsl_import.nix pulls in; `dsh` from the
            # custom AI module set.
            modules.desktop.fonts.enable = true;
            modules.desktop.appcast.enable = true;
            modules.dsh.enable = true;

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
          # common WSL profile
          "home/linux/wsl"
          # host specific
          "home/hosts/linux/${hostName}.nix"
        ]
        ++ [
          {
            # Same paths as the NixOS-level pool above, for the home-manager
            # module tree (home/base/outOfStoreSymlink.nix).
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
    }
    // args
  );

  # WSL importer ISO (`wsl --import`). Eval currently fails on nixpkgs 26.11:
  # NixOS-WSL disables boot.initrd while iso-image.nix references
  # system.build.initialRamdisk unconditionally (upstream fix pending).
  packages.${hostName} = inputs.self.nixosConfigurations.${hostName}.config.system.build.images.iso;
}
