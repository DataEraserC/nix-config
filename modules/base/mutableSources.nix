{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../../lib/mutableSourcesModule.nix ];

  # Home Manager provides this helper in its own module tree. NixOS and Darwin
  # need the equivalent store artifact so callers can share mutableSources.link.
  config.lib.file.mkOutOfStoreSymlink =
    path:
    let
      pathStr = toString path;
      name = lib.strings.sanitizeDerivationName (baseNameOf pathStr);
    in
    pkgs.runCommandLocal name { } "ln -s ${lib.escapeShellArg pathStr} $out";
}
