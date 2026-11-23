{ lib, ... }:
rec {
  colmenaSystem = import ./colmenaSystem.nix;
  macosSystem = import ./macosSystem.nix;
  nixosSystem = import ./nixosSystem.nix;
  nixOnDroidConfiguration = import ./nixOnDroidConfiguration.nix;

  genK3sServerModule = import ./genK3sServerModule.nix;
  genK3sAgentModule = import ./genK3sAgentModule.nix;
  genVmHostModule = import ./genVmHostModule.nix;
  genMicrovmGuestModule = import ./genMicrovmGuestModule.nix;

  systemdHardening = import ./systemdHardening.nix { inherit lib; };
  tools = import ./tools.nix;

  # use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;

  mklinkRelativeToRoot =
    config: FilePath:
    config.lib.mutableSources.link {
      name = "config";
      subpath = FilePath;
      fallback = relativeToRoot FilePath;
    };
  scanPaths =
    path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          path: _type:
          (_type == "directory") # include directories
          || (
            (path != "default.nix") # ignore default.nix
            && (lib.strings.hasSuffix ".nix" path) # include .nix files
          )
        ) (builtins.readDir path)
      )
    );
}
