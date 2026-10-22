{
  # programs.dsh.patch 必须为 null：seeder 的 home 级复制以 homePatchFile != null 为条件，
  # null 是 activation 符号链接存活的前提
  homePatchDisabled = true;
  # provider 行只引用 .credentials.yaml 中的环境变量，不落明文
  ymlHasNoInlineKey = true;
  # activationScripts.dsh-home 用 ln -sfnT 链接 home 级文件
  activationSymlinksHomePatch = true;
  # dsh-home 同时把 cua-driver 的版本匹配 skill 包链接到
  # $DSH_HOME/skills/cua-driver（dsh 用户级 skill 根，NUR 构建直连）
  skillsSymlinksCuaDriver = true;
  # dsh-home 把 cua-cli 的两个 skill（cua-sandboxes / gui-automation）链接到
  # $DSH_HOME/skills/，服务 mcp__cua-mcp__* 沙盒工具面（NUR cua-cli 直连）
  skillsSymlinksCuaSandbox = true;
  # rootless podman + 用户级 API socket：cua-vmm 的引擎入口
  podmanEngineEnabled = true;
  # dsh-cua-sandbox bundle 在 tui profile 的 bundle 列表里
  sandboxBundleInProfile = true;
  # mklinkRelativeToRoot 产出的 store 链接以 cordis.patch.yml 结尾
  homeLinkTargetsCordisPatch = true;
}
