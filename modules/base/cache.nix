# Binary caches shared by NixOS & macOS.
#
# NOTE(fork): 上游（本 fork 的导入提交）原本 import 两个 NUR flake 的 `nixosModules` 输出，这里改为直写：
# 1. flake-parts 给这些输出附加了 `_class = "nixos"`，导入 darwin 模块系统会因 class 不匹配直接报错；
# 2. 两个模块文件声明了相同的内部 key（`xddxdd-nur-packages-nix-cache-attic`），
#    nixpkgs 模块系统按 key 去重，后者（dataeraserc.cachix.org）会被静默丢弃。
# 因此直接读取各家 flake 的 helpers/meta.nix 并写入 nix.settings，两端行为一致且两端都能求值。
{
  nur-xddxdd,
  nur-DataEraserC,
  ...
}:
let
  # xddxdd 的 attic 镜像（保持与 nur-xddxdd 的 helpers/meta.nix 同步）
  attic = import "${nur-xddxdd}/helpers/meta.nix";
  # fork 自己的 cachix（保持与 nur-DataEraserC 的 helpers/meta.nix 同步）
  cachix = import "${nur-DataEraserC}/helpers/meta.nix";
  cacheUrls = [
    attic.atticUrl
    cachix.cachixUrl
  ];
  cacheKeys = [
    attic.atticPublicKey
    cachix.cachixPublicKey
  ];
in
{
  nix.settings = {
    # substituters that will be considered before the official ones(https://cache.nixos.org)
    substituters = cacheUrls;
    trusted-substituters = cacheUrls;
    trusted-public-keys = cacheKeys;
  };
}
