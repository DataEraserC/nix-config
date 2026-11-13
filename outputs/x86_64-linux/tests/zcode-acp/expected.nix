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
    title = "ZCode";
    icon = "terminal";
    processExecutables = [ "node" ];
    commandCount = 3;
    directCommand = {
      match = [ "zcode-cli" ];
      acp = [ "zcode-acp-server" ];
      resume = [
        "zcode-cli"
        "--resume"
      ];
    };
    instanceCommands = [
      {
        match = [
          "multi-instance"
          "zcode-cli"
          "1"
        ];
        acp = [
          "multi-instance"
          "zcode-acp"
          "1"
        ];
        resume = [
          "multi-instance"
          "zcode-cli"
          "1"
          "--resume"
        ];
        launcher = "bwrap";
      }
      {
        match = [
          "multi-instance"
          "zcode-cli"
          "2"
        ];
        acp = [
          "multi-instance"
          "zcode-acp"
          "2"
        ];
        resume = [
          "multi-instance"
          "zcode-cli"
          "2"
          "--resume"
        ];
        launcher = "bwrap";
      }
    ];
  };
}
