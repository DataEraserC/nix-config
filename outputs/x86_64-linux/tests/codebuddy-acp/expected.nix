let
  canonicalInstances = builtins.genList (index: toString (index + 1)) 8;
  canonicalCommand = instanceName: {
    match = [
      "multi-instance"
      "codebuddy-acp"
      instanceName
    ];
    acp = [
      "multi-instance"
      "codebuddy-acp"
      instanceName
      "--acp"
    ];
    resume = [
      "multi-instance"
      "codebuddy-acp"
      instanceName
      "--resume"
    ];
    launcher = "bwrap";
  };
in
{
  module = {
    enabled = true;
    package = "codebuddy-acp";
    version = "1.0.0";
    mainProgram = "codebuddy-acp";
    usesPinnedPackage = true;
    installedPackages = [ "codebuddy-acp" ];
    oldKeyRemoved = true;
  };

  multiInstance = {
    appKeys = [ "codebuddy-acp" ];
    aliases = {
      codebuddy = "codebuddy-acp";
    };
    legacyAppKeyRemoved = true;
    executable = "codebuddy-acp";
    stateDirectoryKey = "codebuddy";
    stateRoot = ".local/state/multi-instance";
    instanceOneStatePath = ".local/state/multi-instance/codebuddy/1";
    paths = [
      ".codebuddy"
      ".local/share/CodeBuddyExtension"
    ];
    persist = [
      ".codebuddy"
      ".local/share/CodeBuddyExtension"
    ];
    preservedPaths = [
      ".local/state/multi-instance"
      ".codebuddy"
      ".local/share/CodeBuddyExtension"
    ];
  };

  webmux = {
    package = "webmux-acp";
    version = "0.16.0-unstable-2026-11-15";
    nurSourceRev = "3f58cc2eb8da7ec13c01444b87352a5458f1c0a5";
    usesPinnedPackage = true;
    declarationEnvironmentKeys = [ "WEBMUX_ACP_AGENTS" ];
    commandCount = 10;
    legacyCommandCount = 1;
    inherit canonicalInstances;
    connectorCommand = {
      match = [ "connector-agent" ];
      acp = [ "connector-agent-acp" ];
      resume = [ "connector-agent-resume" ];
      connector = {
        executable = "connector-agent-acp";
        title = "Connector Agent ACP";
        installCommand = "install connector-agent-acp";
        docsUrl = "https://example.invalid/connector-agent-acp";
      };
    };
    agentKeys = [
      "codebuddy-acp"
      "zcode-acp"
    ];
    title = "CodeBuddy ACP";
    icon = "codebuddy";
    processExecutables = [
      "codebuddy"
      "cbc"
    ];
    commands = [
      {
        match = [ "codebuddy-acp" ];
        acp = [
          "codebuddy-acp"
          "--acp"
        ];
        resume = [
          "codebuddy-acp"
          "--resume"
        ];
      }
      {
        match = [
          "multi-instance"
          "codebuddy"
          "1"
        ];
        acp = [
          "multi-instance"
          "codebuddy"
          "1"
          "--acp"
        ];
        resume = [
          "multi-instance"
          "codebuddy"
          "1"
          "--resume"
        ];
        launcher = "bwrap";
      }
    ]
    ++ map canonicalCommand canonicalInstances;
  };
}
