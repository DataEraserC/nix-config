{
  inputs,
  lib,
  system,
  genSpecialArgs,
  nix-on-droid-modules,
  home-modules ? [ ],
  specialArgs ? (genSpecialArgs system),
  myvars,
  ...
}@args:
let
  inherit (inputs) nix-on-droid nixpkgs home-manager;
in
nix-on-droid.lib.nixOnDroidConfiguration {
  extraSpecialArgs = specialArgs;

  # set nixpkgs instance, it is recommended to apply `nix-on-droid.overlays.default`
  pkgs = import nixpkgs {
    system = "aarch64-linux";

    overlays = [
      nix-on-droid.overlays.default
      # add other overlays
    ]
    ++ (import ../overlays (
      # Spread the flake inputs as top-level args, mirroring what
      # modules/base/overlays.nix provides on NixOS via module args
      # (genSpecialArgs spreads `inputs`); overlays like
      # overlays/nur-ryan4yin.nix take `nur-ryan4yin` directly.
      (args // { feat."nix-on-droid" = true; }) // inputs
    ));
  };

  modules =
    nix-on-droid-modules
    ++ (lib.optionals ((lib.lists.length home-modules) > 0) [
      {
        home-manager = {
          config = {
            imports = home-modules;
          };
          # Set Home Manager Backup Ext
          backupFileExtension = "home-manager.backup";
          useGlobalPkgs = true;
          extraSpecialArgs = specialArgs;
        };
      }
    ]);

  home-manager-path = home-manager.outPath;
}
