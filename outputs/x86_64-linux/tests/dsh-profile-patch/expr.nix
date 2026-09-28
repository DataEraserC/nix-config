{
  lib,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  profiles = cfg.programs.dsh.profiles;
  ymlDir = ../../../../modules/nixos/base/custom;
  repoPatch = key: builtins.readFile (ymlDir + "/dsh/${key}.yml");

  allKeys = [
    "tui"
    "tui-failsafe"
    "web"
    "web-failsafe"
    "web-qq"
    "web-qq-failsafe"
    "web-lan"
    "web-lan-failsafe"
    "web-qq-lan"
    "web-qq-lan-failsafe"
  ];
  nonLanKeys = [
    "tui"
    "tui-failsafe"
    "web"
    "web-failsafe"
    "web-qq"
    "web-qq-failsafe"
  ];
  lanKeys = [
    "web-lan"
    "web-lan-failsafe"
    "web-qq-lan"
    "web-qq-lan-failsafe"
  ];
in
{
  # 全部 10 个 profile 都声明了字符串型 patch（收编自 dsh/<key>.yml）；
  # 若哪个还是默认的 [] 列表，说明漏挂了仓库文件。
  allDeclareRepoPatch = lib.all (key: builtins.isString profiles.${key}.patch) allKeys;

  # 非 LAN profile 的 patch 就是仓库文件原样读入，不掺任何 webserver 行。
  nonLanEqualsRepoFile = lib.all (key: profiles.${key}.patch == repoPatch key) nonLanKeys;

  # LAN profile 的 patch 合并了 Nix 侧的 webserver 行（webLanPatch 在前），
  # 同时保留仓库 yml 的内容（头部注释）。
  lanMergeHasWebserverRow = lib.all (key: lib.hasInfix "id: webserver" profiles.${key}.patch) lanKeys;
  lanMergeKeepsRepoHeader = lib.all (
    key: lib.hasInfix "Profile-level DSH patch" profiles.${key}.patch
  ) lanKeys;

  # 合并时裸 [] 行（当前仓库文件还没有任何行）必须被剔除——否则 webserver
  # 行跟在 flow 序列 [] 后面不是合法的 YAML。
  lanMergeDropsBareEmptySeq = lib.all (key: !(lib.hasInfix "[]" profiles.${key}.patch)) lanKeys;
}
