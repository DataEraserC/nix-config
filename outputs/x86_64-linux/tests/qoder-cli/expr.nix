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
  nurInternational = dataEraserCPackages.qodercli or null;
  nurCn = dataEraserCPackages.qoderclicn or null;
  pinMatches =
    optionPackage: nurPackage: nurPackage != null && toString optionPackage == toString nurPackage;
  app = cfg.modules.multi-instance.apps;
  webmuxEnvironment = cfg.systemd.services.webmux.environment;
  agent = builtins.fromJSON webmuxEnvironment.WEBMUX_ACP_AGENTS;
  cnAgent =
    agent."qoder-cli-cn" or {
      title = null;
      icon = null;
      processExecutables = [ ];
      commands = [ ];
    };
  directoryOf = entry: if builtins.isAttrs entry then entry.directory else entry;
  specLines = lib.splitString "\n" (builtins.readFile cfg.modules.multi-instance.specFile);
  linesWithPrefix = prefix: lib.filter (line: lib.hasPrefix prefix line) specLines;
  cnInstances = builtins.genList (index: toString (index + 1)) 2;
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
  cliPackages = [
    cfg.modules.qodercli.package
    cfg.modules.qoderclicn.package
  ];
  cliPackagesFound = lib.filter (package: package != null) cliPackages;
  installedCommandNames = map (
    package: package.meta.mainProgram or ""
  ) cfg.environment.systemPackages;
in
{
  modules = {
    internationalEnabled = cfg.modules.qodercli.enable;
    cnEnabled = cfg.modules.qoderclicn.enable;
    internationalMainProgram = cfg.modules.qodercli.package.meta.mainProgram;
    cnMainProgram = cfg.modules.qoderclicn.package.meta.mainProgram;
    internationalUsesPinnedPackage = pinMatches cfg.modules.qodercli.package nurInternational;
    cnUsesPinnedPackage = pinMatches cfg.modules.qoderclicn.package nurCn;
    # 1.1.81 is the release whose ACP server answers `--acp`; older builds only
    # accepted `--experimental-acp`, which WebMux never passes.
    acpFlagSupported = lib.all (package: lib.versionAtLeast package.version "1.1.81") cliPackagesFound;
    internationalCommandInstalled = builtins.elem "qodercli" installedCommandNames;
    cnCommandInstalled = builtins.elem "qoderclicn" installedCommandNames;
  };

  apps = {
    international = {
      executable = app.qodercli.executable;
      stateDirectoryKey = app.qodercli.stateDirectoryKey;
      paths = app.qodercli.paths;
      persist = app.qodercli.persist;
      desktop = app.qodercli.desktop;
    };
    cn = {
      executable = app.qoderclicn.executable;
      stateDirectoryKey = app.qoderclicn.stateDirectoryKey;
      paths = app.qoderclicn.paths;
      persist = app.qoderclicn.persist;
      desktop = app.qoderclicn.desktop;
    };
    # The CLI keeps its own login, so its state keys must stay clear of the
    # desktop app keys that share the same brand.
    shareDesktopStateKeys =
      app.qodercli.stateDirectoryKey == app.qoder.stateDirectoryKey
      || app.qoderclicn.stateDirectoryKey == app.qoder-cn.stateDirectoryKey;
    appKeys = lib.filter (name: lib.hasPrefix "qoder" name) (
      lib.attrNames cfg.modules.multi-instance.apps
    );
  };

  spec = {
    internationalLines = linesWithPrefix "qodercli|";
    cnLines = linesWithPrefix "qoderclicn|";
  };

  preservedQoderDirs = lib.unique (
    lib.filter (directory: directory == ".qoder" || directory == ".qoder-cn") (
      map directoryOf cfg.modules.multi-instance.preserveDirectories
    )
  );

  webmux = {
    declarationEnvironmentKeys = lib.filter (lib.hasPrefix "WEBMUX_") (lib.attrNames webmuxEnvironment);
    agentKeys = lib.attrNames agent;
    internationalAgentDeclared = agent ? qodercli;
    cn = {
      title = cnAgent.title;
      icon = cnAgent.icon;
      processExecutables = cnAgent.processExecutables;
      commandCount = builtins.length cnAgent.commands;
      commands = cnAgent.commands;
      expectedCommands = map cnCommand cnInstances;
    };
  };
}
