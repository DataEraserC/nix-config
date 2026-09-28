{
  # programs.dsh.patch 必须为 null：seeder 的 home 级复制以 homePatchFile != null 为条件，
  # null 是 activation 符号链接存活的前提
  homePatchDisabled = true;
  # 仓库 cordis.patch.yml 保留 662 个模型的现网 provider 目录
  ymlDeclaresProvider = true;
  # provider 行只引用 .credentials.yaml 中的环境变量，不落明文
  ymlUsesEnvReference = true;
  ymlHasNoInlineKey = true;
  ymlHasModelRow = true;
  # activationScripts.dsh-cordis-patch 用 ln -sfnT 链接 home 级文件
  activationSymlinksHomePatch = true;
  # mklinkRelativeToRoot 产出的 store 链接以 cordis.patch.yml 结尾
  homeLinkTargetsCordisPatch = true;
}
