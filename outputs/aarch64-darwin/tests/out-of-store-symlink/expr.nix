{
  lib,
  outputs,
  ...
}:
let
  cfg = outputs.darwinConfigurations.fern.config;
  # 实际调用一次，确保 nix-darwin 求值下 pkgs.runCommandLocal 可用
  link = cfg.lib.file.mkOutOfStoreSymlink "/home/nixos/nix-config/home/base/outOfStoreSymlink.nix";
in
{
  darwinLibFileExists = builtins.isFunction (cfg.lib.file.mkOutOfStoreSymlink or null);
  darwinCallReturnsDrv = lib.isDerivation link;
  darwinLinkBasename = lib.hasSuffix "outOfStoreSymlink.nix" (toString link);
  # darwin 主机未声明池，enable 取选项默认值
  poolEnabled = cfg.modules.outOfStoreSymlink.enable;
}
