{
  # 10 个 profile 全部挂上仓库 yml（isString，而非默认 [] 列表）。
  allDeclareRepoPatch = true;

  # 非 LAN profile 的 patch 与仓库文件逐字节一致。
  nonLanEqualsRepoFile = true;

  # 4 个 LAN profile 都合并进了 webserver 行。
  lanMergeHasWebserverRow = true;

  # 合并结果保留了仓库 yml 的头部注释。
  lanMergeKeepsRepoHeader = true;

  # 裸 [] 行在合并时被剔除（webserver 行紧跟注释，序列合法）。
  lanMergeDropsBareEmptySeq = true;
}
