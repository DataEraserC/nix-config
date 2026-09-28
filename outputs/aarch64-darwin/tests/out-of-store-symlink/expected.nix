{
  # nix-darwin 侧同样由 modules/base/outOfStoreSymlink.nix 提供该函数
  darwinLibFileExists = true;
  darwinCallReturnsDrv = true;
  darwinLinkBasename = true;
  poolEnabled = true;
}
