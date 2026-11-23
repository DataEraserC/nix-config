{
  lib,
  mylib,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.wsl-work.config;
  link = cfg.lib.mutableSources.link {
    name = "config";
    subpath = "modules/nixos/base/custom/ai/dsh/default.nix";
    fallback = mylib.relativeToRoot "modules/nixos/base/custom/ai/dsh/default.nix";
  };
in
{
  wslLibExists = builtins.isFunction (cfg.lib.mutableSources.link or null);
  wslCallReturnsDrv = lib.isDerivation link;
  wslLinkBasename = lib.hasSuffix "default.nix" (toString link);
  wslSourcesEnabled = cfg.modules.mutableSources.enable;
  wslConfigSource = cfg.modules.mutableSources.sources.config.external;
}
