{
  lib,
  outputs,
  ...
}:
let
  cfg = outputs.darwinConfigurations.fern.config;
  directLink = cfg.lib.file.mkOutOfStoreSymlink "/home/nixos/nix-config/home/base/mutableSources.nix";
  fallback = cfg.lib.mutableSources.resolve {
    name = "missing";
    fallback = "/immutable/fallback";
  };
  legacyCfg =
    (outputs.darwinConfigurations.fern.extendModules {
      modules = [
        {
          modules.outOfStoreSymlink.paths.configPath = "/tmp/legacy-config";
        }
      ];
    }).config;
  legacyDisabledCfg =
    (outputs.darwinConfigurations.fern.extendModules {
      modules = [
        {
          modules.outOfStoreSymlink.enable = false;
        }
      ];
    }).config;
in
{
  darwinLibFileExists = builtins.isFunction (cfg.lib.file.mkOutOfStoreSymlink or null);
  mutableSourcesLibExists = builtins.isFunction (cfg.lib.mutableSources.link or null);
  darwinCallReturnsDrv = lib.isDerivation directLink;
  darwinLinkBasename = lib.hasSuffix "mutableSources.nix" (toString directLink);
  fallbackIsDirect = fallback == "/immutable/fallback";
  legacyPathMapsToConfig = legacyCfg.lib.mutableSources.resolve { name = "config"; };
  legacyDisableMaps = !legacyDisabledCfg.modules.mutableSources.enable;
  sourcesEnabled = cfg.modules.mutableSources.enable;
}
