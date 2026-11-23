{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.mutableSources;
  pathType = lib.types.nullOr (lib.types.either lib.types.str lib.types.path);

  validSubpath =
    subpath: !lib.hasPrefix "/" subpath && !(builtins.elem ".." (lib.splitString "/" subpath));
  appendSubpath =
    base: subpath: if subpath == "" then toString base else "${toString base}/${subpath}";

  select =
    {
      name,
      subpath ? "",
      fallback ? null,
    }:
    let
      _ =
        if validSubpath subpath then
          null
        else
          throw "mutableSources.${name}: subpath must be relative and must not contain '..': ${subpath}";
      source = cfg.sources.${name} or null;
      useExternal = cfg.enable && source != null && source.external != null;
      configuredFallback = if source != null then source.fallback else null;
      path =
        if useExternal then
          appendSubpath source.external subpath
        else if fallback != null then
          toString fallback
        else if configuredFallback != null then
          appendSubpath configuredFallback subpath
        else
          null;
    in
    builtins.seq _ {
      inherit path;
      mutable = useExternal;
    };

  resolve = args: (select args).path;
  link =
    args:
    let
      selected = select args;
    in
    if selected.path == null then
      throw "mutableSources.${args.name}: no external source or fallback is configured"
    else if selected.mutable then
      config.lib.file.mkOutOfStoreSymlink selected.path
    else
      lib.warn "mutableSources.${args.name}: using immutable fallback ${selected.path}" selected.path;
in
{
  options.modules.mutableSources = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Prefer configured mutable external sources over immutable fallbacks.";
    };

    sources = lib.mkOption {
      default = { };
      description = "Named mutable source roots and their optional immutable fallbacks.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            external = lib.mkOption {
              type = pathType;
              default = null;
              description = "Writable source outside the Nix store.";
            };

            fallback = lib.mkOption {
              type = pathType;
              default = null;
              description = "Immutable source used when the external source is disabled or absent.";
            };
          };
        }
      );
    };
  };

  config = {
    lib.mutableSources = {
      inherit link resolve;
    };

    warnings = lib.flatten (
      lib.mapAttrsToList (
        name: source:
        lib.optionals (cfg.enable && lib.isPath source.external) [
          "mutableSources.${name}.external is a Nix path; use a string so it remains outside the store"
        ]
      ) cfg.sources
    );
  };
}
