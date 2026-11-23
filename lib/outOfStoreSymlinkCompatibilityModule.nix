{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.outOfStoreSymlink;
  canonicalName =
    name:
    {
      configPath = "config";
      wallpaperPath = "wallpapers";
      passwordStorePath = "passwordStore";
    }
    .${name} or name;
in
{
  imports = [
    (lib.mkRenamedOptionModule
      [ "modules" "outOfStoreSymlink" "enable" ]
      [ "modules" "mutableSources" "enable" ]
    )
  ];

  options.modules.outOfStoreSymlink.paths = lib.mkOption {
    type = lib.types.attrsOf (lib.types.nullOr (lib.types.either lib.types.str lib.types.path));
    default = { };
    description = "Deprecated compatibility pool for modules.mutableSources.sources.";
  };

  config = {
    modules.mutableSources.sources = lib.mapAttrs' (
      name: value:
      lib.nameValuePair (canonicalName name) {
        external = lib.mkDefault value;
      }
    ) cfg.paths;

    warnings = lib.optional (cfg.paths != { }) (
      "modules.outOfStoreSymlink.paths is deprecated; use modules.mutableSources.sources"
    );
  };
}
