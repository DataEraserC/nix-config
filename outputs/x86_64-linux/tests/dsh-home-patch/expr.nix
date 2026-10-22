{
  lib,
  inputs,
  mylib,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  yml = builtins.readFile ../../../../modules/nixos/base/custom/ai/dsh/common.yml;
  activation = cfg.system.activationScripts.dsh-home.text;
  homeLink = mylib.mklinkRelativeToRoot cfg "modules/nixos/base/custom/ai/dsh/common.yml";
  # NUR 侧 cua-driver 源构建（dsh 模块直连 nur-DataEraserC 的包）
  nurCuaDriver = inputs.nur-DataEraserC.packages.x86_64-linux.cua-driver;
  # NUR 侧 cua-cli 预编译包（二进制 + skills）
  nurCuaCli = inputs.nur-DataEraserC.packages.x86_64-linux.cua-cli;
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
  # 同一个脚本把 cua-driver 包里的 skill 包链接到 $DSH_HOME/skills/cua-driver，
  # 且钉死的是 NUR 包的 outPath：dsh 模块刻意直连 nur-DataEraserC 而不是全局
  # `cua-driver` overlay 别名——别名留给上游的预编译版（i3 computer-use 宿主
  # 走 X11，不需要 portal-capture），而 dsh 需要源构建的 portal-capture、随包
  # 的 skill 包、和与 experimental provider 匹配的版本。谁把模块"简化"回用
  # 别名，skill 链接就会悬空（预编译版根本不装 skills），这条断言立刻红。
  # activation 是普通字符串故 match 的正则无 context；与 outPath 的相等比较
  # 不构造正则，带 context 的路径也能参与，因此认的是完整 store 路径而不是
  # 名字，与版本号无关。
  skillsSymlinksCuaDriver =
    let
      captured = lib.match ".*(/nix/store/[a-z0-9]+-cua-driver-[0-9.]+)/share/cua-driver-skills.*" activation;
    in
    captured != null && builtins.head captured == nurCuaDriver.outPath;
  # dsh-cua-sandbox 的两个 skill（cua-sandboxes 工作流 + gui-automation 命令
  # 参考）同样钉在 NUR cua-cli 的 outPath 上：技能与 bundle 的 runtimeDeps
  # 钉同一个 store 路径，版本切换时两边一起换，不会出现"技能讲 0.6、二进制
  # 是 0.7"的漂移。断言方式同上：正则里不出现带 context 的插值。
  skillsSymlinksCuaSandbox =
    let
      capturedSandboxes = lib.match ".*(/nix/store/[a-z0-9]+-cua-cli-[0-9.]+)/share/cua-skills/cua-sandboxes.*" activation;
      capturedGui = lib.match ".*(/nix/store/[a-z0-9]+-cua-cli-[0-9.]+)/share/cua-skills/gui-automation.*" activation;
    in
    capturedSandboxes != null
    && builtins.head capturedSandboxes == nurCuaCli.outPath
    && capturedGui != null
    && builtins.head capturedGui == nurCuaCli.outPath;
  # cua 沙盒引擎：cua-vmm 走 Podman 的 docker 兼容 API socket，nixpkgs 的
  # podman 模块只接系统 socket，rootless 的这对用户单元（socket 激活，ListenStream
  # 在 $XDG_RUNTIME_DIR/podman/podman.sock —— cua-vmm 的 well-known 候选之一）
  # 由 dsh 模块自己声明。少任何一半，sandbox_create 都会在调用时报"找不到引擎"。
  podmanEngineEnabled =
    let
      socket = cfg.systemd.user.sockets.podman;
      service = cfg.systemd.user.services.podman;
    in
    cfg.virtualisation.podman.enable
    && lib.hasInfix "podman/podman.sock" (toString socket.socketConfig.ListenStream)
    && lib.hasInfix "podman system service" (toString service.serviceConfig.ExecStart);
  # dsh-cua-sandbox 必须落在 tui profile 的 bundle 列表里（mcp__cua-mcp__*
  # 工具面的载体）：模型看得见沙盒工具，才谈得上"操持 podman sandbox"。
  sandboxBundleInProfile =
    let
      names = map (b: b.name or "") cfg.programs.dsh.profiles.tui.bundles;
    in
    lib.any (n: lib.hasInfix "dsh-cua-sandbox" n) names;
  # mkOutOfStoreSymlink 的 toString 是 store 路径，其名字 = 源文件 basename
  homeLinkTargetsCordisPatch = lib.hasSuffix "common.yml" (toString homeLink);
}
