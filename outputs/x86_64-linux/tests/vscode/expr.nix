{
  lib,
  myvars,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  homeCfg = cfg.home-manager.users.${myvars.username};
  vscodePackages = lib.filter (
    package:
    lib.hasPrefix "vscode" (package.pname or package.name or "")
    && (package.meta.mainProgram or "") == "code"
  ) homeCfg.home.packages;
in
{
  moduleEnabled = homeCfg.modules.vscode.enable;
  passwordStore = homeCfg.modules.vscode.passwordStore;
  enabled = homeCfg.programs.vscode.enable;
  packageCount = builtins.length vscodePackages;
  mainProgram = homeCfg.programs.vscode.package.meta.mainProgram or null;
}
