{
  lib,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.wsl-work.config;
  # dsh 所在的 WSL 主机是该 helper 的直接消费方，故实际调用一次
  link = cfg.lib.file.mkOutOfStoreSymlink "/home/nixos/nix-config/modules/nixos/base/custom/ai/dsh/default.nix";
in
{
  wslLibFileExists = builtins.isFunction (cfg.lib.file.mkOutOfStoreSymlink or null);
  wslCallReturnsDrv = lib.isDerivation link;
  # mkOutOfStoreSymlink 的 toString 是 store 路径，名字 = 源文件 basename
  wslLinkBasename = lib.hasSuffix "default.nix" (toString link);
  wslPoolEnabled = cfg.modules.outOfStoreSymlink.enable;
  wslPoolConfigPath = cfg.modules.outOfStoreSymlink.paths.configPath;
}
