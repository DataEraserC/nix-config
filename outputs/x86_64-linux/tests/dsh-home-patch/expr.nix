{
  lib,
  mylib,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  yml = builtins.readFile ../../../../modules/nixos/base/custom/cordis.patch.yml;
  activation = cfg.system.activationScripts.dsh-cordis-patch.text;
  homeLink = mylib.mklinkRelativeToRoot cfg "modules/nixos/base/custom/cordis.patch.yml";
in
{
  # patch 必须保持 null：seed 脚本只在声明了 home patch（homePatchFile != null）
  # 时才会 copy_owned_file 覆盖 $DSH_HOME/cordis.patch.yml（validate_owned_file
  # 遇到符号链接直接 die），null 才能让 activation 的链接在每次 dsh 启动后存活。
  homePatchDisabled = cfg.programs.dsh.patch == null;
  # 仓库 yml 即黄金内容：模型目录行与现网 provider
  ymlDeclaresProvider = lib.hasInfix "new-api-y9000p2025" yml;
  ymlUsesEnvReference = lib.hasInfix "apiKeyEnv: NEW_API_Y9000P2025_API_KEY" yml;
  # 密钥只以环境变量引用存在，不允许出现裸 apiKey: 行
  ymlHasNoInlineKey = !(lib.hasInfix "apiKey:" yml);
  ymlHasModelRow = lib.hasInfix "llm-pi-ai" yml;
  # activation 负责把仓库文件链接到 $DSH_HOME/cordis.patch.yml
  activationSymlinksHomePatch =
    lib.hasInfix "ln -sfnT" activation && lib.hasInfix "cordis.patch.yml" activation;
  homeLinkTargetsCordisPatch = lib.hasSuffix "cordis.patch.yml" (toString homeLink);
}
