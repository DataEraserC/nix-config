{
  lib,
  config,
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
  config.warnings = lib.flatten (
    lib.mapAttrsToList (
      key: value:
      lib.optionals (cfg.enable && lib.isPath value) [
        "if ${key} is a path, mkOutOfStoreSymlink may not work"
      ]
    ) cfg.paths
  );
}
