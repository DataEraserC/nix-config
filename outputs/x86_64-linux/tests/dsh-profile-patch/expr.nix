{
  lib,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  profiles = cfg.programs.dsh.profiles;
  ymlDir = ../../../../modules/nixos/base/custom/ai;
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
in
{
  # 全部 10 个 profile 都声明了字符串型 patch（收编自 dsh/<key>.yml）；
  # 若哪个还是默认的 [] 列表，说明漏挂了仓库文件。
  allDeclareRepoPatch = lib.all (key: builtins.isString profiles.${key}.patch) allKeys;

  # 每个 profile 的 patch 就是仓库文件原样读入：Nix 侧不再向任何档注入行。
  # LAN 档与普通档的唯一区别是启动时的选择，不是 patch 内容。
  everyProfileEqualsRepoFile = lib.all (key: profiles.${key}.patch == repoPatch key) allKeys;

  # 反向锁定：任何 profile 都不能再自带 webserver 行。web-app bundle 已提供该行，
  # 而 patch 对同一 id 是整块替换 config（dsh-app-boot 的 applyEntryPatches 是
  # `target[key] = value`，不是深合并），本地再写一份会静默丢掉未复述的键——
  # 包括 `tls`（`--tls-cert`/`--tls-key` 会失效且无报错）。
  noProfileDeclaresWebserverRow = lib.all (
    key: !(lib.hasInfix "id: webserver" profiles.${key}.patch)
  ) allKeys;
}
