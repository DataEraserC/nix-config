{
  lib,
  mylib,
  myvars,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  hmCfg = cfg.home-manager.users.${myvars.username};

  # 共享 helper 分别以 NixOS config 和 home-manager config 调用，
  # 两者都必须能解析出 config.lib.file.mkOutOfStoreSymlink（此前仅 HM 侧提供）。
  sysLink = mylib.mklinkRelativeToRoot cfg "modules/base/outOfStoreSymlink.nix";
  hmLink = mylib.mklinkRelativeToRoot hmCfg "home/base/outOfStoreSymlink.nix";
in
{
  nixosLibFileExists = builtins.isFunction (cfg.lib.file.mkOutOfStoreSymlink or null);
  hmLibFileExists = builtins.isFunction (hmCfg.lib.file.mkOutOfStoreSymlink or null);
  poolEnabled = cfg.modules.outOfStoreSymlink.enable;
  poolConfigPath = cfg.modules.outOfStoreSymlink.paths.configPath;
  sysHelperReturnsDrv = lib.isDerivation sysLink;
  hmHelperReturnsDrv = lib.isDerivation hmLink;
  sysLinkBasename = lib.hasSuffix "outOfStoreSymlink.nix" (toString sysLink);
}
