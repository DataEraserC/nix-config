let
  instances = builtins.genList (index: toString (index + 1)) 6;
  instanceCommand = instanceName: {
    match = [
      "multi-instance"
      "zcode-acp"
      instanceName
    ];
    acp = [
      "multi-instance"
      "zcode-acp"
      instanceName
    ];
    resume = [
      "multi-instance"
      "zcode-acp-resume"
      instanceName
    ];
    launcher = "bwrap";
  };
in
{
  module = {
    enabled = true;
    package = "zcode-acp";
    version = "0.89.0";
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
      "zcode-acp-resume"
      "zcode-cli"
    ];
    acpExecutable = "zcode-acp";
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
      "qoder-cli-cn"
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
      ]
      ++ map instanceCommand instances;
    };
  };
}
