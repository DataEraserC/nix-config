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
}:
let
  inherit (inputs) nix-on-droid nixpkgs home-manager;
in
nix-on-droid.lib.nixOnDroidConfiguration {
  extraSpecialArgs = specialArgs;

  # set nixpkgs instance, it is recommended to apply `nix-on-droid.overlays.default`
  pkgs = import nixpkgs {
    inherit system;

    # Unfree packages are allowed on the same terms as the NixOS/darwin
    # instances (outputs/default.nix nixpkgsConfig): the droid home profile
    # ships corefonts and other unfree-redistributable packages.
    config.allowUnfree = true;

    overlays = [
      nix-on-droid.overlays.default
      # add other overlays
    ]
    ++ (import ../overlays (
      # The shared overlays/ take the same args the NixOS module tree gives
      # them: specialArgs is genSpecialArgs' output, which spreads the flake
      # inputs (overlays like overlays/nur-ryan4yin.nix take `nur-ryan4yin`
      # directly) plus mylib/myvars/pkgs-stable; `lib` itself is injected by
      # the NixOS module system, so pass it explicitly here.
      # `feat."nix-on-droid"` switches the droid-only overlays on.
      specialArgs
      // {
        inherit lib;
        feat."nix-on-droid" = true;
      }
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
