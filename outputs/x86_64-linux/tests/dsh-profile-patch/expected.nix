{
  # 10 个 profile 全部挂上仓库 yml（isString，而非默认 [] 列表）。
  allDeclareRepoPatch = true;

  # 每个 profile 的 patch 与仓库文件逐字节一致（Nix 侧不注入任何行）。
  everyProfileEqualsRepoFile = true;

  # 反向锁定：没有任何 profile 自带 webserver 行——该行由 web-app bundle 提供，
  # 本地复述会整块替换 config 并静默丢掉 tls 等未复述的键。
  noProfileDeclaresWebserverRow = true;
}
