{
  linkNames = [
    "acb-harnesses"
    "dsh-cua-sandboxes"
    "dsh-gui-automation"
    "dsh-home-patch"
  ];
  cordisSource = "config";
  cordisSubpath = "modules/nixos/base/custom/ai/dsh/common.yml";
  cordisTarget = "/home/nixos/.dsh/cordis.patch.yml";
  acbSource = "agentChatBridge";
  acbSubpath = "harnesses";
  activationAfterDshHome = true;
  activationAfterAcbDirs = true;
  acbParentGuard = true;
  dshParentGuard = true;
  skipsInitrd = true;
  activationUsesManifest = true;
  manifestIsDerivation = true;
  statePreserved = true;
}
