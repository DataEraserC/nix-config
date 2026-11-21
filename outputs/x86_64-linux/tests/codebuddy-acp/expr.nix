{
  inputs,
  lib,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  system = cfg.nixpkgs.hostPlatform.system;
  dataEraserCPackages = inputs.nur-DataEraserC.legacyPackages.${system};
  webmuxEnvironment = cfg.systemd.services.webmux.environment;
  agent = builtins.fromJSON webmuxEnvironment.WEBMUX_ACP_AGENTS;
  codebuddy = agent.codebuddy-acp;
  canonicalCommands = lib.filter (
    command:
    builtins.length command.match == 3
    && builtins.elemAt command.match 0 == "multi-instance"
    && builtins.elemAt command.match 1 == "codebuddy-acp"
  ) codebuddy.commands;
  legacyCommands = lib.filter (
    command:
    command.match == [
      "multi-instance"
      "codebuddy"
      "1"
    ]
  ) codebuddy.commands;
  accountApp = cfg.modules.multi-instance.apps.codebuddy-acp;
  accountAliases = cfg.modules.multi-instance.aliases;
  stateRoot = cfg.modules.multi-instance.stateRoot;
  directoryOf = entry: if builtins.isAttrs entry then entry.directory else entry;
  persistedDirectories = map directoryOf accountApp.persist;
  preservedDirectories = map directoryOf cfg.modules.multi-instance.preserveDirectories;
  usesPinnedCodeBuddyPackage =
    toString cfg.modules.codebuddy-acp.package == toString dataEraserCPackages.codebuddy-acp;
  usesPinnedWebMuxPackage =
    toString cfg.modules.webmux.package == toString dataEraserCPackages.webmux-acp;
  codebuddyPackages = lib.filter (package: lib.hasPrefix "codebuddy" (package.pname or "")) (
    cfg.environment.systemPackages
  );
  connectorTestConfig =
    (outputs.nixosConfigurations.ai-niri.extendModules {
      modules = [
        {
          modules.webmux.acpAgents.connector-test = {
            title = "Connector Test";
            processExecutables = [ "connector-native" ];
            commands = [
              {
                match = [ "connector-agent" ];
                acp = [ "connector-agent-acp" ];
                resume = [ "connector-agent-resume" ];
                connector = {
                  executable = "connector-agent-acp";
                  title = "Connector Agent ACP";
                  installCommand = "install connector-agent-acp";
                  docsUrl = "https://example.invalid/connector-agent-acp";
                  verifiedVersion = null;
                };
              }
            ];
          };
        }
      ];
    }).config;
  connectorTestAgent = builtins.fromJSON (
    connectorTestConfig.systemd.services.webmux.environment.WEBMUX_ACP_AGENTS
  );
  connectorTest = builtins.head connectorTestAgent.connector-test.commands;
in
{
  module = {
    enabled = cfg.modules.codebuddy-acp.enable;
    package = cfg.modules.codebuddy-acp.package.pname;
    version = cfg.modules.codebuddy-acp.package.version;
    mainProgram = cfg.modules.codebuddy-acp.package.meta.mainProgram;
    usesPinnedPackage = usesPinnedCodeBuddyPackage;
    installedPackages = map (package: package.pname) codebuddyPackages;
    oldKeyRemoved = !(builtins.hasAttr "codebuddy" cfg.modules);
  };

  multiInstance = {
    appKeys = lib.filter (name: lib.hasInfix "codebuddy" name) (
      lib.attrNames cfg.modules.multi-instance.apps
    );
    aliases = lib.filterAttrs (
      name: canonical: lib.hasInfix "codebuddy" name || lib.hasInfix "codebuddy" canonical
    ) accountAliases;
    legacyAppKeyRemoved = !(builtins.hasAttr "codebuddy" cfg.modules.multi-instance.apps);
    inherit (accountApp) executable stateDirectoryKey;
    inherit stateRoot;
    instanceOneStatePath = "${stateRoot}/${accountApp.stateDirectoryKey}/1";
    paths = accountApp.paths;
    persist = persistedDirectories;
    preservedPaths = lib.filter (
      path: path == stateRoot || builtins.elem path accountApp.paths
    ) preservedDirectories;
  };

  webmux = {
    package = cfg.modules.webmux.package.pname;
    version = cfg.modules.webmux.package.version;
    nurSourceRev = inputs.nur-DataEraserC.rev;
    usesPinnedPackage = usesPinnedWebMuxPackage;
    declarationEnvironmentKeys = lib.filter (lib.hasPrefix "WEBMUX_") (lib.attrNames webmuxEnvironment);
    commandCount = builtins.length codebuddy.commands;
    legacyCommandCount = builtins.length legacyCommands;
    canonicalInstances = map (command: builtins.elemAt command.match 2) canonicalCommands;
    connectorCommand = connectorTest;
    agentKeys = lib.attrNames agent;
    inherit (codebuddy)
      title
      icon
      processExecutables
      commands
      ;
  };
}
