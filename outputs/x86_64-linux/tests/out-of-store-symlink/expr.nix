{
  lib,
  mylib,
  myvars,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  hmCfg = cfg.home-manager.users.${myvars.username};
  linkArgs = {
    name = "config";
    subpath = "modules/base/mutableSources.nix";
    fallback = mylib.relativeToRoot "modules/base/mutableSources.nix";
  };
  sysLink = cfg.lib.mutableSources.link linkArgs;
  hmLink = hmCfg.lib.mutableSources.link (
    linkArgs
    // {
      subpath = "home/base/mutableSources.nix";
      fallback = mylib.relativeToRoot "home/base/mutableSources.nix";
    }
  );
  legacyCfg =
    (outputs.nixosConfigurations.ai-niri.extendModules {
      modules = [
        {
          modules.outOfStoreSymlink.paths.configPath = "/tmp/legacy-config";
        }
      ];
    }).config;
  fallbackCfg =
    (outputs.nixosConfigurations.ai-niri.extendModules {
      modules = [
        {
          modules.mutableSources = {
            enable = lib.mkForce false;
            sources.fallbackRoot.fallback = "/immutable/root";
          };
        }
      ];
    }).config;
in
{
  nixosLibExists = builtins.isFunction (cfg.lib.mutableSources.link or null);
  hmLibExists = builtins.isFunction (hmCfg.lib.mutableSources.link or null);
  sourcesEnabled = cfg.modules.mutableSources.enable;
  configSource = cfg.modules.mutableSources.sources.config.external;
  resolvedConfig = cfg.lib.mutableSources.resolve {
    name = "config";
    subpath = "flake.nix";
  };
  canonicalSourceWinsLegacyDefault =
    legacyCfg.lib.mutableSources.resolve { name = "config"; } == "/home/nixos/nix-config";
  callSiteFallbackIsComplete =
    fallbackCfg.lib.mutableSources.resolve {
      name = "config";
      subpath = "flake.nix";
      fallback = mylib.relativeToRoot "flake.nix";
    } == toString (mylib.relativeToRoot "flake.nix");
  configuredFallbackIsRoot =
    fallbackCfg.lib.mutableSources.resolve {
      name = "fallbackRoot";
      subpath = "file";
    } == "/immutable/root/file";
  sysHelperReturnsDrv = lib.isDerivation sysLink;
  hmHelperReturnsDrv = lib.isDerivation hmLink;
  sysLinkBasename = lib.hasSuffix "mutableSources.nix" (toString sysLink);
}
