{
  lib,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  links = cfg.modules.managedLinks.links;
  activation = cfg.system.activationScripts.managedLinks;
  directoryOf = entry: if builtins.isAttrs entry then entry.directory else entry;
  preserved = map directoryOf cfg.preservation.preserveAt."/persistent".directories;
in
{
  linkNames = builtins.attrNames links;
  cordisSource = links.dsh-home-patch.sourceName;
  cordisSubpath = links.dsh-home-patch.subpath;
  cordisTarget = links.dsh-home-patch.target;
  acbSource = links.acb-harnesses.sourceName;
  acbSubpath = links.acb-harnesses.subpath;
  activationAfterDshHome = builtins.elem "dsh-home" activation.deps;
  activationAfterAcbDirs = builtins.elem "acb-dirs" activation.deps;
  acbParentGuard = lib.hasInfix "refusing symlinked parent" cfg.system.activationScripts.acb-dirs.text;
  dshParentGuard = lib.hasInfix "refusing symlinked parent" cfg.system.activationScripts.dsh-home.text;
  activationUsesManifest =
    lib.hasInfix "managed_links.py" activation.text
    && lib.hasInfix "/var/lib/nix-config/managed-links/manifest.json" activation.text;
  manifestIsDerivation = lib.isDerivation cfg.system.build.managedLinksManifest;
  statePreserved = builtins.elem "/var/lib/nix-config/managed-links" preserved;
}
