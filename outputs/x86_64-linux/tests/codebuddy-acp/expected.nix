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
    version = "0.14.4-unstable-2026-11-11";
    nurSourceRev = "b1a5a7179c6f61b59e1867a75efb9a01e9dfb16c";
    usesPinnedPackage = true;
    declarationEnvironmentKeys = [ "WEBMUX_ACP_AGENTS" ];
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
    agentKeys = [ "codebuddy-acp" ];
    title = "CodeBuddy";
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
      {
        match = [
          "multi-instance"
          "codebuddy-acp"
          "1"
        ];
        acp = [
          "multi-instance"
          "codebuddy-acp"
          "1"
          "--acp"
        ];
        resume = [
          "multi-instance"
          "codebuddy-acp"
          "1"
          "--resume"
        ];
        launcher = "bwrap";
      }
    ];
  };
}
