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
  directoryOf = entry: if builtins.isAttrs entry then entry.directory else entry;
  acpApp = cfg.modules.multi-instance.apps.zcode-acp;
  cliApp = cfg.modules.multi-instance.apps.zcode-cli;
  # `executable = null` means "use the app key" (resolved with command -v at
  # runtime); compare what the launcher actually runs, not the raw option.
  resolvedExecutable = name: app: if app.executable == null then name else app.executable;
  guiApp = cfg.modules.multi-instance.apps.zcode;
  stateRoot = cfg.modules.multi-instance.stateRoot;
  preservedDirectories = map directoryOf cfg.modules.multi-instance.preserveDirectories;
in
{
  module = {
    enabled = cfg.modules.zcode-acp.enable;
    package = cfg.modules.zcode-acp.package.pname;
    version = cfg.modules.zcode-acp.package.version;
    mainProgram = cfg.modules.zcode-acp.package.meta.mainProgram;
    usesPinnedPackage =
      toString cfg.modules.zcode-acp.package == toString dataEraserCPackages.zcode-acp;
    vendorCliPname = cfg.modules.zcode-acp.vendorCli.pname or null;
    vendorCliInstalled = builtins.elem cfg.modules.zcode-acp.vendorCli cfg.environment.systemPackages;
    guiModuleEnabled = cfg.modules.zcode.enable;
    guiEditionKeysRemoved =
      !(builtins.hasAttr "zcode-cn" cfg.modules) && !(builtins.hasAttr "zcode-intl" cfg.modules);
  };

  multiInstance = {
    appKeys = lib.filter (name: lib.hasPrefix "zcode" name) (
      lib.attrNames cfg.modules.multi-instance.apps
    );
    acpExecutable = resolvedExecutable "zcode-acp" acpApp;
    cliExecutable = resolvedExecutable "zcode-cli" cliApp;
    sharedStateKey = acpApp.stateDirectoryKey == cliApp.stateDirectoryKey;
    stateDirectoryKey = cliApp.stateDirectoryKey;
    stateRoot = stateRoot;
    instanceOneStatePath = "${stateRoot}/${cliApp.stateDirectoryKey}/1";
    paths = cliApp.paths;
    guiStateKey = if guiApp.stateDirectoryKey == null then "zcode" else guiApp.stateDirectoryKey;
    preservedPaths = lib.filter (path: path == stateRoot || builtins.elem path cliApp.paths) (
      lib.unique preservedDirectories
    );
  };

  # Direct-only binding: the terminal side is the bridge's Martty TUI
  # (bin/zcode-acp under a TTY); the official bundled CLI has no TUI.
  webmux = {
    agentKeys = lib.attrNames agent;
    zcode = agent.zcode-acp;
  };
}
