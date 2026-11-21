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

  # If the out-of-store symlink is enabled and `key` exists in the variable pool,
  # link `paths.${key}/${subpath}` (writable); otherwise fall back to `defaultSource`.
  mkSymlinkOrFallback =
    config: key: subpath: defaultSource:
    let
      root = config.modules.outOfStoreSymlink.paths.${key} or null;
    in
    if config.modules.outOfStoreSymlink.enable && root != null then
      (lib.warn "mkOutOfStoreSymlink ${root}/${subpath}" config.lib.file.mkOutOfStoreSymlink (
        if subpath == "" then root else "${root}/${subpath}"
      ))
    else
      (lib.warn "direct use ${defaultSource}" defaultSource);

  mklinkRelativeToRoot =
    config: FilePath: mkSymlinkOrFallback config "configPath" FilePath (relativeToRoot FilePath);
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
