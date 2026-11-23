{
  lib,
  inputs,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  yml = builtins.readFile ../../../../modules/nixos/base/custom/ai/dsh/common.yml;
  activation = cfg.system.activationScripts.dsh-home.text;
  homePatchLink = cfg.modules.managedLinks.links.dsh-home-patch;
  homeLink = cfg.lib.mutableSources.link {
    name = homePatchLink.sourceName;
    inherit (homePatchLink) subpath fallback;
  };
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
  # managedLinks owns the target; dsh-home only prepares its parent and must not
  # create an unmanaged link that the manifest cannot later clean.
  managedLinksOwnsHomePatch =
    homePatchLink.target == "/home/nixos/.dsh/cordis.patch.yml"
    && !(lib.hasInfix "ln -sfnT" activation && lib.hasInfix "cordis.patch.yml" activation);
  # dsh-cua-driver 停用（DS-012：cua-driver 启动时把 org.a11y.Status.IsEnabled
  # 翻成 true，GNOME 随即拉起 Orca）。两处必须一起保持关闭：bundle 不在任何
  # profile 的 bundle 列表里，$DSH_HOME/skills/cua-driver 也不再链接（activation
  # 还会清掉旧 generation 留下的链接）。重新启用时两处一起恢复，把这两条断言
  # 改回正向即可。
  cuaDriverBundleDisabled = lib.all (
    p: !(lib.any (n: lib.hasInfix "dsh-cua-driver" n) (map (b: b.name or "") p.bundles))
  ) (lib.attrValues cfg.programs.dsh.profiles);
  cuaDriverSkillRemoved = !(lib.hasInfix "cua-driver-skills" activation);
  # dsh-cua-sandbox 的两个 skill（cua-sandboxes 工作流 + gui-automation 命令
  # 参考）同样钉在 NUR cua-cli 的 outPath 上：技能与 bundle 的 runtimeDeps
  # 钉同一个 store 路径，版本切换时两边一起换，不会出现"技能讲 0.6、二进制
  # 是 0.7"的漂移。断言方式：正则里不出现带 context 的插值。
  skillsManagedByCuaPackage =
    let
      sandboxSource = toString cfg.modules.managedLinks.links.dsh-cua-sandboxes.source;
      guiSource = toString cfg.modules.managedLinks.links.dsh-gui-automation.source;
    in
    lib.hasPrefix nurCuaCli.outPath sandboxSource
    && lib.hasSuffix "/share/cua-skills/cua-sandboxes" sandboxSource
    && lib.hasPrefix nurCuaCli.outPath guiSource
    && lib.hasSuffix "/share/cua-skills/gui-automation" guiSource;
  # cua 沙盒引擎：cua-vmm 走 Podman 的 docker 兼容 API socket，
  # $XDG_RUNTIME_DIR/podman/podman.sock 是它的 well-known 候选之一。
  #
  # 这对 rootless 用户单元由 nixpkgs 的 podman 模块交付，不是 dsh 模块：
  # virtualisation.podman 用 `systemd.packages = [ cfg.package ]` 装 podman 自带的
  # podman.socket / podman.service，又用 systemd.user.sockets.podman.wantedBy 在
  # sockets.target 下启用。所以这里断言的是"模块开关打开后用到的引擎可用"，
  # 而不是"dsh 模块自己拼了 unit 字符串"——后者曾是错的实现，见下。
  #
  # 真正会炸的是 ExecStart 重复：nixpkgs 的生成器会把 services.podman 渲染成
  # podman.service.d/overrides.conf 这个 drop-in，一旦它也带 ExecStart，包自带的
  # service 加上它就有两条，systemd 直接拒绝启动（"Service has more than one
  # ExecStart= setting, which is only allowed for Type=oneshot services"）。
  # 断言因此钉住两件事：包自带的两个 unit 确实存在（引擎真的可用），且模块
  # 这一侧既不补 ExecStart 也不补 ListenStream（不会叠出第二条）。
  podmanEngineEnabled =
    let
      podmanPkg = cfg.virtualisation.podman.package;
      service = cfg.systemd.user.services.podman;
      socket = cfg.systemd.user.sockets.podman;
      # 包自带的两个 unit（rootless socket + socket-activated service）。
      pkgUnits = [
        "${podmanPkg}/lib/systemd/user/podman.socket"
        "${podmanPkg}/lib/systemd/user/podman.service"
      ];
      # 模块这一侧不得再补 ExecStart/ListenStream：nixpkgs 会把
      # systemd.user.services.<name> 渲染成 drop-in，与包自带 unit 相加就有两条。
      noExecStart = (service.serviceConfig.ExecStart or null) == null;
      noListenStream = (socket.socketConfig.ListenStream or null) == null;
    in
    cfg.virtualisation.podman.enable
    && lib.all lib.pathExists pkgUnits
    && noExecStart
    && noListenStream
    && socket.wantedBy == [ "sockets.target" ];
  # dsh-cua-sandbox 必须落在 tui profile 的 bundle 列表里（mcp__cua-mcp__*
  # 工具面的载体）：模型看得见沙盒工具，才谈得上"操持 podman sandbox"。
  sandboxBundleInProfile =
    let
      names = map (b: b.name or "") cfg.programs.dsh.profiles.tui.bundles;
    in
    lib.any (n: lib.hasInfix "dsh-cua-sandbox" n) names;
  # mkOutOfStoreSymlink 的 toString 是 store 路径，其名字 = 源文件 basename
  homeLinkTargetsCommonYml = lib.hasSuffix "common.yml" (toString homeLink);
}
