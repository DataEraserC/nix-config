{
  module = {
    enabled = true;
    package = "zcode-acp";
    version = "0.84.3";
    mainProgram = "zcode-acp-server";
    usesPinnedPackage = true;
    vendorCliPname = "zcode-cli";
    vendorCliInstalled = true;
    guiModuleEnabled = true;
    guiEditionKeysRemoved = true;
  };

  multiInstance = {
    appKeys = [
      "zcode"
      "zcode-acp"
      "zcode-cli"
    ];
    acpExecutable = "zcode-acp-server";
    cliExecutable = "zcode-cli";
    sharedStateKey = true;
    stateDirectoryKey = "zcode-cli";
    stateRoot = ".local/state/multi-instance";
    instanceOneStatePath = ".local/state/multi-instance/zcode-cli/1";
    paths = [
      ".zcode"
    ];
    guiStateKey = "zcode";
    preservedPaths = [
      ".local/state/multi-instance"
      ".zcode"
    ];
  };

  webmux = {
    agentKeys = [
      "codebuddy-acp"
      "zcode-acp"
    ];
    zcode = {
      title = "ZCode";
      icon = "terminal";
      processExecutables = [
        "node"
        "bun"
      ];
      commands = [
        {
          match = [ "zcode-acp" ];
          acp = [ "zcode-acp-server" ];
          resume = [ "zcode-acp-resume" ];
        }
      ];
    };
  };
}
