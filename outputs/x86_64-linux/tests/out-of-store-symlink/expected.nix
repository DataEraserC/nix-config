{
  # NixOS 侧的 config.lib.file.mkOutOfStoreSymlink 由 modules/base/outOfStoreSymlink.nix 提供
  nixosLibFileExists = true;
  # HM 侧仍由 home-manager 自带的 modules/files.nix 提供
  hmLibFileExists = true;
  poolEnabled = true;
  poolConfigPath = "/home/nixos/nix-config";
  # mklinkRelativeToRoot 对系统配置与 HM 配置都应返回 store 内符号链接 derivation
  sysHelperReturnsDrv = true;
  hmHelperReturnsDrv = true;
  # 符号链接 derivation 以被链接文件的 basename 命名
  sysLinkBasename = true;
}
