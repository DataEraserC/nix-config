{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.modules.outOfStoreSymlink;
in
{
  options = {
    modules.outOfStoreSymlink = {
      enable = mkOption {
        default = true;
        type = lib.types.bool;
        description = lib.mdDoc "use mkOutOfStoreSymlink instead for link file can make file writable";
      };
      paths = mkOption {
        type = lib.types.attrsOf (lib.types.nullOr (lib.types.either lib.types.str lib.types.path));
        default = { };
        description = lib.mdDoc "variable pool of roots for out-of-store symlinks, e.g. configPath, wallpaperPath, passwordStorePath";
      };
    };
  };
  # home-manager provides config.lib.file.mkOutOfStoreSymlink in its own module
  # tree (modules/files.nix), but the system module tree has no equivalent, so
  # mylib.mkSymlinkOrFallback / mklinkRelativeToRoot could not be called with a
  # NixOS/darwin config. Define the same helper here: it yields a store path
  # whose only content is a symlink to the real out-of-store file, so the link
  # target stays writable without copying it into the store.
  config.lib.file.mkOutOfStoreSymlink =
    path:
    let
      pathStr = toString path;
      name = lib.strings.sanitizeDerivationName (baseNameOf pathStr);
    in
    pkgs.runCommandLocal name { } "ln -s ${lib.escapeShellArg pathStr} $out";

  config.warnings = lib.flatten (
    lib.mapAttrsToList (
      key: value:
      lib.optionals (cfg.enable && lib.isPath value) [
        "if ${key} is a path, mkOutOfStoreSymlink may not work"
      ]
    ) cfg.paths
  );
}
