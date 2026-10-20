{
  lib,
  mylib,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  yml = builtins.readFile ../../../../modules/nixos/base/custom/ai/dsh/common.yml;
  activation = cfg.system.activationScripts.dsh-cordis-patch.text;
  homeLink = mylib.mklinkRelativeToRoot cfg "modules/nixos/base/custom/ai/dsh/common.yml";
in
{
  # patch 必须保持 null：seed 脚本只在声明了 home patch（homePatchFile != null）
  # 时才会 copy_owned_file 覆盖 $DSH_HOME/cordis.patch.yml（validate_owned_file
  # 遇到符号链接直接 die），null 才能让 activation 的链接在每次 dsh 启动后存活。
  homePatchDisabled = cfg.programs.dsh.patch == null;
  # common.yml 现在只承载机器级 rows（当前为空 []，模型目录已收编进各 profile
  # 的 <key>.yml，由 dsh-profile-patch 测试覆盖）；密钥只允许以环境变量引用
  # 存在，不允许出现裸 apiKey: 行。
  ymlHasNoInlineKey = !(lib.hasInfix "apiKey:" yml);
  # activation 负责把仓库文件链接到 $DSH_HOME/cordis.patch.yml
  activationSymlinksHomePatch =
    lib.hasInfix "ln -sfnT" activation && lib.hasInfix "cordis.patch.yml" activation;
  # mkOutOfStoreSymlink 的 toString 是 store 路径，其名字 = 源文件 basename
  homeLinkTargetsCordisPatch = lib.hasSuffix "common.yml" (toString homeLink);
}
