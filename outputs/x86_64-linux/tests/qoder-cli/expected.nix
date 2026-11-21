let
  cnInstances = [
    "1"
    "2"
  ];
  cnCommand = instanceName: {
    match = [
      "multi-instance"
      "qoderclicn"
      instanceName
    ];
    acp = [
      "multi-instance"
      "qoderclicn"
      instanceName
      "--acp"
    ];
    resume = [
      "multi-instance"
      "qoderclicn"
      instanceName
      "--resume"
    ];
    launcher = "bwrap";
  };
in
{
  modules = {
    # The China edition is the one this host runs; the international module
    # exists and stays off, exactly like `modules.qoder`.
    internationalEnabled = false;
    cnEnabled = true;
    internationalMainProgram = "qodercli";
    cnMainProgram = "qoderclicn";
    internationalUsesPinnedPackage = true;
    cnUsesPinnedPackage = true;
    acpFlagSupported = true;
    internationalCommandInstalled = false;
    cnCommandInstalled = true;
  };

  apps = {
    international = {
      executable = null;
      stateDirectoryKey = "qoder-cli";
      paths = [ ".qoder" ];
      persist = [ ".qoder" ];
      desktop = null;
    };
    cn = {
      executable = null;
      stateDirectoryKey = "qoder-cn-cli";
      paths = [ ".qoder-cn" ];
      persist = [ ".qoder-cn" ];
      desktop = null;
    };
    shareDesktopStateKeys = false;
    appKeys = [
      "qoder"
      "qoder-cn"
      "qoder-cn-ide"
      "qoder-ide"
      "qodercli"
      "qoderclicn"
    ];
  };

  # cli-key | resolved executable | state directory key | redirected paths
  spec = {
    internationalLines = [ "qodercli|qodercli|qoder-cli|.qoder" ];
    cnLines = [ "qoderclicn|qoderclicn|qoder-cn-cli|.qoder-cn" ];
  };

  # The IDE, the desktop app and the CLI of each edition all name the same user
  # directory, and the preservation set still holds one entry per path.
  preservedQoderDirs = [
    ".qoder"
    ".qoder-cn"
  ];

  webmux = {
    declarationEnvironmentKeys = [ "WEBMUX_ACP_AGENTS" ];
    agentKeys = [
      "codebuddy-acp"
      "qoder-cli-cn"
      "zcode-acp"
    ];
    internationalAgentDeclared = false;
    cn = {
      title = "Qoder CLI CN";
      icon = "qoder";
      processExecutables = [ "qoderclicn" ];
      commandCount = 2;
      commands = map cnCommand cnInstances;
      expectedCommands = map cnCommand cnInstances;
    };
  };
}
