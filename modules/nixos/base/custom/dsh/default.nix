{
  pkgs,
  deepseek-harness,
  nur-DataEraserC,
  # qq-bridge fork 源码的 path input（详见 flake.nix 的 qq-bridge-fork）
  qq-bridge-fork,
  config,
  myvars,
  lib,
  mylib,
  ...
}:
let
  cfg = config.modules.dsh;

  # 用 fork（flake input qq-bridge-fork）覆盖 qq-bridge-unwrapped 的 src，再喂给
  # 下面三处 .override 的 unwrapped 参数，让 bridge 服务、DSH MCP servers、
  # agent presets 三件套都跑 fork 代码（新工具 qq_get_message_media）。刻意用
  # overrideAttrs 而不是改 nur 侧的 default.nix：qq-bridge-unwrapped 文件与上游
  # 保持逐字一致，nix-update / 自动更新不受影响。
  qqBridgeForkUnwrapped =
    nur-DataEraserC.packages.${pkgs.system}.qq-bridge-unwrapped.overrideAttrs
      (_: {
        src = builtins.path {
          path = qq-bridge-fork;
          # 解包目录必须叫 source：buildDshBundle 的 sourceRoot 写死
          # "source/plugins/..."，而目录型 src 是按 store 名字拷出来的
          # （fetchFromGitHub 的 tarball 解包后也是 source）。
          name = "source";
          # 不把 .git 与依赖目录带进 store（依赖 0.1.5→0.1.7 未变，运行时 node_modules
          # 由构建期 npm 流水线生成）。
          filter =
            path: _type:
            let
              base = baseNameOf path;
            in
            base != "node_modules" && base != ".git";
        };
      });

  # TEMP: modlens 3.26.5 的反向 MiMo 门（issue #80：裸 ID 视为原生 omni、须带
  # -pro 段）把 mimo-v2.6-flash-free 挡在 (modlens vision) 变体之外，路由即使
  # 已声明 modality 也一并否决。opencode2dsh 侧的硬编码 ["text"] 已过时：
  # zen-adapter 的 isVisionModel 对 mimo-v2.6 声明 ['text','image']，dsh 传原生
  # 图片字节；openai-compat 路由仍默认纯文本 —— 未声明 modality 的渠道传不了图。
  # 补丁与 fork DataEraserC/modlens@ce6db0e 的 dsh/index.js 修改一致：路由声明了
  # modality 时以声明为准（image 已在上一行被否决，text-only 即不可能传图），门
  # 只在 modality 缺失时按名字判。上游发布含该修复的版本后，删掉本绑定并把两处
  # 引用改回 nur 包。
  modlensPatched = nur-DataEraserC.packages.${pkgs.system}.modlens.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      patch --no-backup-if-mismatch -p1 < ${./modlens-mimo-gate.patch}
    '';
  });

  # Pinned fork commit instead of local patch files: the upstream repo did
  # not merge the PRs we needed, and three stacked patch files were a
  # maintenance burden (context drift on every upstream tag). The fork branch
  # `master-patches` (rev pinned below) is now a true MERGE of upstream
  # master (0.3.5 era, b69e25d) with our IP-pool line — both histories stay
  # reachable, future upstream syncs are ordinary merges, and GitHub shows
  # 0 behind. The first two picks below (#14, #23) were adopted upstream
  # during that sync (1f270f4 / 36e83bb), so the only content delta against
  # upstream is the pool line; the commits in order:
  #
  #  - opencode2dsh#14 (author superzzm2026, cherry-picked with -x): ZenAdapter
  #    never implements imageRequestPricing(), so dsh-llm's pricing lookup
  #    throws "TypeError: ... imageRequestPricing is not a function" on every
  #    /compact (manual or automatic).
  #
  #  - opencode2dsh#23 (dsh-017, author W1ngD1nGa5ter, cherry-picked with -x):
  #    DSH 0.1.7 removed the client's `settingsScope` service, so the plugin
  #    parked at `pending (waiting for service: settingsScope)` and the IP 池
  #    settings card never appeared. Moves the client onto `configForms` and
  #    bumps @deepseek-ai/dsh-client-ui-settings to 0.1.7-rc.2 (schemastery ≥
  #    3.18.4 is required at runtime for `IpPoolConfigSchema.volatile()`), so
  #    pnpm-lock.yaml and the fixed-output pnpmDeps hash change with it.
  #
  #  - local singbox force-TLS fix (commit authored here, Assisted-by trailer):
  #    buildOutbound() only emitted a `tls` block when the Clash entry carried
  #    tls/sni/fingerprint, but hysteria2 and tuic are QUIC+TLS protocols that
  #    sing-box rejects with "TLS required" — and real subscriptions do ship
  #    hy2 entries with neither flag (the HK-HY2 node of xn--m7r52rosihxm.com
  #    has no sni), failing `sing-box check` for the whole config and stalling
  #    every subscription node at 待转换. Forces TLS on for both types the way
  #    anytls already did (GoProxy forceTLS).
  #
  #  - ports-follow-use lifecycle (0.4.0, Assisted-by trailer): disable now
  #    stops the supervisor (the old path only swapped the dispatcher back and
  #    leaked the child plus every loopback port), an idle sweep stops it after
  #    singbox.idleStopMs without pool use (default 10min, 0 = always on), and
  #    reload is serialized + idempotent (an unchanged 30min subscription
  #    refresh no longer respawns the child). Dispatch to a stopped core serves
  #    direct and wakes it; probing wakes it before the first byte. Adds the
  #    singBoxRunning status field and the card's idle-stop knob. The commit
  #    also vendors the upstream Windows-path test fixture (3 tests were
  #    unrunnable on Linux). pnpmDeps hash UNCHANGED: the fixed-output output
  #    is a pure pnpm store snapshot keyed by the lockfile (package.json
  #    version is not an input). Caveat — that snapshot is only as complete as
  #    one good fetch: npm throttling in the sandbox makes pnpm silently drop
  #    optional platform bindings, and a degraded store hashes just as
  #    "valid", failing prepack later with rolldown MODULE_NOT_FOUND for
  #    @rolldown/binding-linux-x64-gnu. Fix: delete the -opencode2dsh-pnpm-deps
  #    output and rebuild until the store index lists that binding.
  #
  #  - settings save + routing engagement (0.4.1, Assisted-by trailer): the
  #    card's diff no longer drops a write that equals the composition base —
  #    the pool's base default is enabled: false, so toggling the switch OFF
  #    produced zero writes, Save stayed disabled and the served value never
  #    flipped back (the original 无法保存 report: on saves, off never does).
  #    Exit routing now also engages from pool occupancy regardless of source:
  #    install() gates on total>0, which is false at boot for a
  #    subscription-only pool (free's onAdmitted retry never fires for
  #    free-dry pools) and still false during an enable flip (conversions
  #    land after the gate) — 247 converted exits sat with every loopback
  #    port open while the dispatcher install was never called (live:
  #    enabled=false, empty deferredReason). installWhenOccupied() runs after
  #    enable-flip conversions and on the 30s sweep, throttled to 60s.
  #    diffWrites moved to a pure module with 6 regression tests.
  #
  #  - R1 self-lock + leaked runtime + cold enable (0.4.2, Assisted-by
  #    trailer): three live-observed defects from the 0.4.1 verification.
  #    (a) The real undici setGlobalDispatcher returns void, so #previous
  #    was never captured, disable() skipped the restore and our router
  #    lingered in the global slot — the next install() read its OWN layer
  #    as a foreign owner (deferredReason "owned by PoolRoutingDispatcher"
  #    forever, while a stale router kept routing). Fixed: pre-swap capture
  #    via getGlobalDispatcher, fallback to a fresh default Agent on
  #    disable (setGlobalDispatcher(undefined) throws UND_ERR_INVALID_ARG),
  #    and a stale own-name layer is adopted instead of deferred.
  #    (b) ensureRuntime had no in-flight memo: a boot apply racing
  #    loader/volatile-update fired two startIpPool calls and leaked a
  #    second runtime with live timers and its own installer (status and
  #    routing each telling a different story). (c) The enable flip never
  #    pre-warmed the child: plaintext exits are loopback ports of
  #    sing-box, so the first requests after saving all failed with
  #    Connection error before the on-demand spawn could win the race;
  #    wakes now also create the supervisor on demand. 3 regression tests
  #    fail on the old code.
  #
  #  - K-lane port ceiling (0.5.0, Assisted-by trailer): the per-node
  #    inbound shape made 260 subscription nodes occupy 30001-30262
  #    permanently — 端口占用本身就是冗余 (user decision: only bind a local
  #    port when actually dialing). generateConfig now emits K local SOCKS5
  #    lanes (singbox.lanes, default 16, knob 1-64) plus N port-less
  #    outbounds with stable content-derived tags behind per-lane
  #    selectors, plus experimental.clash_api.external_controller — local
  #    ports = K + 1 constant regardless of node count, and still only
  #    while the child runs (ports follow use unchanged). LanePool binds a
  #    node to a free lane with a millisecond clash-API selector switch
  #    (affects new dials only; in-flight keep-alive streams measured
  #    untouched); dispatcher/admission/probing borrow lanes with a 10s
  #    queue, epoch-stamped bindings that drop the per-lane agent on every
  #    rebind, and a direct fallback on every failure path (never
  #    fail-closed). Disable/crash/reset voids all bindings. Lane changes
  #    respawn the child (sameNodes idempotency now includes the lane
  #    count). Docs §1.2.4. pnpmDeps hash UNCHANGED: the lockfile is
  #    byte-identical (package.json version is not a pnpm-store input).
  #
  # The first two commits keep their upstream author/message; the later ones
  # are ours. Rebase the fork branch onto the next upstream tag when
  # nur-DataEraserC catches up, then drop this override entirely. `patches = [ ]`
  # clears whatever upstream adds later, so only the pinned tree ships.
  opencode2dsh = nur-DataEraserC.packages.${pkgs.system}.opencode2dsh.overrideAttrs (
    old:
    let
      # db1f4d2 = 946ac03 + the empty-proxyHosts fix (Assisted-by trailer):
      # the schema resolves ipPool.proxyHosts to [] when the profile omits
      # it, and the router constructor's `?? DEFAULT` kept that empty array
      # — new Set([]).has(host) failed for EVERY host, so all zen traffic
      # routed direct and 429 concentrated on one Clash exit IP while the
      # pool and status card looked green (live-observed 2026-10-02). An
      # empty array now defaults exactly like setProxyHosts, and the status
      # bridge prefers the LIVE router's set over settings/fallback so the
      # two can never diverge silently again. No dependency changes: the
      # pnpmDeps fixed-output hash is unchanged (lockfile byte-identical to
      # 946ac03).
      forkSrc = pkgs.fetchFromGitHub {
        owner = "DataEraserC";
        repo = "opencode2dsh";
        rev = "db1f4d270c449ebc8dda5bfe28fbfebcf7c4a84e";
        hash = "sha256-NcCTuXm9Wlo0QKnc+QxVHaOplLJIWW5YZFuPZ//C56U=";
      };
    in
    {
      src = forkSrc;
      patches = [ ];
      pnpmDeps = old.pnpmDeps.override {
        src = forkSrc;
        # pnpmDeps patches are empty: the fork tree already carries the
        # lockfile change. Hash matches the patched lockfile (schemastery
        # 3.18.4 / dsh-client-ui-settings 0.1.7-rc.2 resolution).
        patches = [ ];
        hash = "sha256-oTImIPNGDoTxZnUdgGqRe0hU/cJz2rjnMbaM3Jv/iuw=";
      };
    }
  );

  # Entry: each surface owns its own launcher bundle, so a profile restates
  # its entry instead of inheriting the other surface's. The plugin packages
  # themselves are hoisted once under `$DSH_HOME/profiles/node_modules`.
  tuiEntry = [ pkgs.dsh.bundles.tui ];
  webEntry = [
    pkgs.dsh.bundles.web-app
    pkgs.dsh.bundles.web-ui
  ];

  # Base shared by every profile of both surfaces: interface-agnostic
  # plugins that are known to work everywhere. A `*-failsafe` profile is the
  # composition without `extraBundles` — `<entry> ++ baseBundles` on the
  # plain surfaces, plus `qqBundles` on the qq combos — the fallback when one
  # of the extras below breaks the composition. modsearch is the essential
  # search replacement and belongs in every profile; without it dsh's search
  # capability is crippled.
  baseBundles = [
    pkgs.dsh.bundles.modsearch
    pkgs.dsh.bundles.remote
  ];

  # Extras shared by the full `tui` and `web` profiles: optional plugins
  # layered on top of the base. Later bundles override earlier Cordis
  # configuration, so keep risky additions here — the failsafe profiles
  # omit this list entirely. The unstable QQ stack lives in `qqBundles`
  # below and ships only in the `web-qq*` profiles.
  extraBundles = [
    # Snapshot the profile patch document and replay Settings-UI edits that
    # dsh-sync-profiles reverts on managed profiles: restores happen only
    # while the .nix-managed fingerprint still matches, so a `just local`
    # nix change still wins. Headless and zero-dependency, but kept out of
    # the *-failsafe profiles so the escape hatch stays a pure baseline.
    nur-DataEraserC.packages.${pkgs.system}.dsh-settings-persist
    nur-DataEraserC.packages.${pkgs.system}.dsh-turn-rewind
    # Retired: cliproxyapi is no longer deployed.
    # pkgs.dsh.bundles.cpa
    # Incompatible with the current kernel; keep disabled until it is fixed.
    # pkgs.dsh.bundles.message-edit
    # dsh.nix pins 0.1.21 (peer ranges stop before DSH 0.2.0-rc.2); the nur package
    # carries upstream's fixed 0.1.22. Drop back once deepseek-harness.nix catches up.
    nur-DataEraserC.packages.${pkgs.system}.dsh-agent-teams
    # pkgs.dsh.bundles.ads
    # Archived: dsh ships a built-in navbar implementation now.
    # pkgs.dsh.bundles.navbar
    opencode2dsh
    nur-DataEraserC.packages.${pkgs.system}.dsh-bas-remote
    # nur-DataEraserC.packages.${pkgs.system}.dsh-git-worktree
    nur-DataEraserC.packages.${pkgs.system}.dsh-worktree
    modlensPatched
    # nur-DataEraserC.packages.${pkgs.system}.dsh-oauthpro
    # only work on 0.1.7-alpha.1 || 0.1.7-alpha.2 || 0.1.7-rc.1 || 0.1.7-rc.2
    # nur-DataEraserC.packages.${pkgs.system}.dsh-notifier
    # pkgs.dsh.bundles.chat-import
    # pkgs.dsh.bundles.annotation
    nur-DataEraserC.packages.${pkgs.system}.dsh-chat-import
    nur-DataEraserC.packages.${pkgs.system}.dsh-annotation
    # Chrome-driven browser automation (ego_* tools). runtimeDeps pins
    # google-chrome onto the dsh launcher PATH so auto-detect works even when
    # dsh starts without the user profile PATH; chromePath / EGO_LINUX_CHROME
    # remain the manual override. The optional sidebar partner
    # pkgs.dsh.bundles.better-sidebar stays off — the floating observe ball
    # is the fallback.
    nur-DataEraserC.packages.${pkgs.system}.dsh-ego-browser
    pkgs.dsh.bundles.harbor
    pkgs.dsh.bundles.graph-memory
  ];

  # QQ group-chat stack: unstable, so it stays out of the plain profiles and
  # ships only in the `web-qq*` combos — layered after `extraBundles` in the
  # full combo, used in place of them in the failsafe combos. Group chat
  # drives dsh through opencode2dsh, so the bridge pairs with it and needs
  # nothing beyond the shared entry and base.
  qqBundles = [
    opencode2dsh
    (nur-DataEraserC.packages.${pkgs.system}.qq-bridge-dsh.override {
      qqBridgeHome = "/home/${myvars.username}/.local/share/qq-bridge";
      unwrapped = qqBridgeForkUnwrapped;
    })
    # Agent presets (qq-chat / qq-chat-v2) own the execution-time guard
    # since they became their own bundle: QQ presets' qq-tool-restrict.mjs
    # rejects anything outside its whitelist — admit modlens' vision tool
    # and modsearch's search surface here: `web_search` is the dsh built-in
    # whose provider modsearch swaps, `x_search` / `read_page` are modsearch's
    # additions (exact names → SAFE_EXACT; dev_* stays denied no matter what).
    # The override moved here with the guard implementation.
    # dsh-ego-browser's 33 registered ego_* tools split by surface: the 24
    # browser-observation/interaction ones below go to the allow list, the 9
    # local-execution / local-file / credential / host-state ones go to
    # extraRestrictedTools — guard-only rejection still leaves the name in the
    # model schema where it baits sim sessions, so they must be hidden by the
    # same restrict path as dev_*. The two lists must stay disjoint.
    (nur-DataEraserC.packages.${pkgs.system}.qq-agent-presets.override {
      extraAllowedTools = [
        "modlens_read_image"
        "web_search"
        "x_search"
        "read_page"
        "ego_captcha"
        "ego_check"
        "ego_click"
        "ego_dialog"
        "ego_drag"
        "ego_fill"
        "ego_help"
        "ego_hover"
        "ego_http"
        "ego_js"
        "ego_key"
        "ego_navigate"
        "ego_page_info"
        "ego_read_element"
        "ego_screenshot"
        "ego_scroll"
        "ego_select"
        "ego_snapshot"
        "ego_space_close"
        "ego_space_open"
        "ego_wait"
        "ego_wait_for_response"
        "ego_wait_for_selector"
        "ego_wait_for_url"
      ];
      extraRestrictedTools = [
        "ego_auth_flush"
        "ego_cdp"
        "ego_cli"
        "ego_doctor"
        "ego_download"
        "ego_login_import"
        "ego_script"
        "ego_status"
        "ego_upload"
      ];
      # presets 的 src 跟随 unwrapped.src
      unwrapped = qqBridgeForkUnwrapped;
    })
    nur-DataEraserC.packages.${pkgs.system}.qq-mode-console
    # The group-chat server launch must write dsh stdout to
    # `~/.dsh/guard/logs/server-<stamp>.out.log`: with `dsh.authToken`
    # left empty, qq-bridge discovers the DSH launch token from the newest
    # file matching that exact pattern, and re-discovers after a 401 or a
    # restart. The log home, the `server-<stamp>.out.log` naming, and its
    # retention are all provided by dsh-plugin-guard — web-qq depends on
    # it for exactly that part. Unstable otherwise; parked commented out,
    # enable for web-qq once validated.
    # nur-DataEraserC.packages.${pkgs.system}.dsh-plugin-guard
  ];

  tuiBundles = tuiEntry ++ baseBundles ++ extraBundles;
  tuiFailsafeBundles = tuiEntry ++ baseBundles;
  webBundles = webEntry ++ baseBundles ++ extraBundles;
  webFailsafeBundles = webEntry ++ baseBundles;
  # The qq combos: `web-qq` is the whole web stack plus the QQ stack, so a
  # single instance covers both uses and no second dsh is needed alongside
  # it; the failsafe keeps entry + base + qq and drops only the shared
  # extras. `lib.unique` removes the opencode2dsh that both `extraBundles`
  # and `qqBundles` carry — a bundle listed twice would patch the
  # composition twice.
  webQQBundles = lib.unique (webBundles ++ qqBundles);
  webQQFailsafeBundles = webFailsafeBundles ++ qqBundles;

  # The webserver row patched to bind every interface, shared by the two
  # LAN profiles. dsh refuses `--host 0.0.0.0` at startup, so the bind
  # host can come neither from the command line nor from
  # `services.dsh.listenAddress`; this profile layer is the only seam.
  #
  # Reachability is then the firewall's decision: 3080 is not in
  # `allowedTCPPorts`, so only `trustedInterfaces` (tailscale0, zt5u4z6wb4,
  # easytier0) reach it. A 0.0.0.0 bind also makes dsh derive every
  # non-internal IPv4 into its browser-trust fence, so the overlay
  # addresses need no `trustedHosts` entry.
  #
  # `host` is pinned on purpose, so `--host` has no effect here; the port
  # keeps the row's own override so `--port` still works. Start it
  # deliberately rather than by default:
  #   dsh --profile nix-web-lan --no-open
  webLanPatch = ''
    - id: webserver
      config:
        host: 0.0.0.0
        port: !!js ctx.webStartup.port ?? 3080
        compression: gzip
        compressionLevel: 1
        compressionThresholdBytes: 1024
  '';

  # Every profile's `cordis.patch.yml` rows come from the file
  # `<key>.yml` in this directory (dotfile-style: edit + prettier + `just local`).
  # Mode stays `managed`, so the profile file on disk is a store snapshot of
  # that repo file and is restored on the next launch — in-place edits never
  # persist by design.
  repoPatch = key: builtins.readFile (./${key}.yml);

  # Compose a LAN profile's patch: the Nix webserver row first, the repo yml
  # rows after it, so a same-id row declared in the git file wins. The yml's
  # %YAML/--- document header cannot follow a document that already started,
  # so strip those lines, and strip a bare `[]` (no rows yet) for the same
  # reason; `#` comments are legal between items and survive verbatim.
  mergeWebLan =
    yml: web:
    let
      isHeaderLine =
        line: builtins.match "%YAML.*" line != null || builtins.match "---[[:space:]]*" line != null;
      isBareEmptySeq = line: builtins.match "[[:space:]]*[][[:space:]]*" line != null;
      keepLine = line: !(isHeaderLine line || isBareEmptySeq line);
    in
    web + "\n" + lib.concatStringsSep "\n" (lib.filter keepLine (lib.splitString "\n" yml));

  # 主页>插件 的卡片过滤是 `installed = dependencies.includes(name)`（读 profile
  # package.json 顶层 dependencies），可上游 resolve-dsh-bundles.mjs 的 profile
  # 子命令把 dependencies 写死成 {}，nix 同步出的 profile 从不声明 extraBundles —
  # 于是这些插件在插件页根本不出现，IP 池那行配置（plugins.row.config）也无从进入。
  # 这里在 nix 侧补：构建期读 extraBundles/baseBundles/qqBundles 各 bundle 的
  # nix-support/dsh-bundles.json，把 本 profile bundles ∩ 名单 的 {name: version}
  # 写进模板 dependencies，并按 makeProfileTemplate 同一算法重算 .nix-managed
  # 指纹 —— dsh-sync-profiles 的 no-op 判定照常成立（无每次启动的回写循环），
  # 上游 seeder 只做路径替换、其余逐字保留。交集保证“拥有”不越界：baseBundles
  # 本就全档加载（含 *-failsafe，出卡是如实标注），qqBundles 只落 web-qq*，
  # 纯 extras 仍绕开 plain *-failsafe；enabled（= dsh.profile.bundles）不受影响，
  # 注入只改 dependencies 这个“已安装”标记。不改上游 deepseek-harness.nix 任何文件。
  #
  # 【何时可删】上游满足任一条件即可删掉本函数与 programs.dsh.package 覆盖：
  #   ① resolve-dsh-bundles.mjs 的 profile 子命令把 bundle manifest 的
  #      {name, version} 写进 dependencies（新模板 deps 不再是 {}）；或
  #   ② 插件页 installed 判定把 installation.dependencies / selected 并进来
  #      （selected-only 或安装锚点依赖也算已安装）。
  # 验收命令：nix build --no-link --print-out-paths
  #   '.#nixosConfigurations.<host>.config.programs.dsh.package.passthru.profileTemplates'
  #   出来后任一模板 jq -c .dependencies 非 {} 即上游已修。
  patchProfileDeps =
    artifacts:
    let
      injectedManifests = map (bundle: "${bundle}/nix-support/dsh-bundles.json") (
        lib.unique (extraBundles ++ baseBundles ++ qqBundles)
      );
      targetNames = map (spec: spec.targetName) (lib.attrValues artifacts.profileSpecs);
      patchedTemplates =
        pkgs.runCommand "deepseek-harness-profiles-with-deps"
          {
            nativeBuildInputs = [
              pkgs.coreutils
              pkgs.jq
            ];
          }
          ''
            set -euo pipefail

            # name → manifest version，只收 extra/base/qq 三个名单的 manifest；
            # profiles 用下面的交集再筛一遍，只留该档 bundles 真在跑的名字。
            extraDeps=./extra-deps.json
            printf '{}\n' > "$extraDeps"
            for manifest in ${lib.escapeShellArgs injectedManifests}; do
              jq -r '.bundles[] | [.name, .version] | @tsv' "$manifest" |
                while IFS=$'\t' read -r name version; do
                  tmp=$(mktemp)
                  jq --arg name "$name" --arg version "$version" '.[$name] = $version' \
                    "$extraDeps" > "$tmp"
                  mv "$tmp" "$extraDeps"
                done
            done

            mkdir -p "$out"
            for target in ${lib.escapeShellArgs targetNames}; do
              mkdir -p "$out/$target"
              cp --dereference --no-preserve=mode -r \
                ${artifacts.profileTemplates}/"$target"/. "$out/$target/"
              jq --slurpfile extra "$extraDeps" '
                . as $profile
                | .dependencies = (.dependencies + ($extra[0]
                    | to_entries
                    | map(select(.key as $name
                        | $profile.dsh.profile.bundles | index($name) != null))
                    | from_entries))
              ' "$out/$target/package.json" > "$out/$target/package.json.tmp"
              mv "$out/$target/package.json.tmp" "$out/$target/package.json"
              # 与 makeProfileTemplate 相同的指纹算法，模板内容变了就重算。
              fingerprint=$(
                cd "$out/$target"
                sha256sum -- package.json cordis.patch.yml pnpm-workspace.yaml | sha256sum | cut -d' ' -f1
              )
              {
                printf 'owner=nix\n'
                printf 'schema=1\n'
                printf 'profile=%s\n' "$target"
                printf 'fingerprint=%s\n' "$fingerprint"
              } > "$out/$target/.nix-managed"
            done
          '';
      # 上游 seeder 把模板集合路径烤进了脚本；只 sed 换成补过的集合，sync 逻辑
      # 逐字保留，上游更新时自动跟随。替换后残留原路径则直接 fail（防上游改了
      # 路径拼接方式而这里悄悄失效）。
      patchedSeeder =
        pkgs.runCommand "dsh-sync-profiles-with-deps"
          {
            nativeBuildInputs = [
              pkgs.coreutils
              pkgs.gnugrep
            ];
          }
          ''
            set -euo pipefail
            mkdir -p "$out/bin"
            sed 's|${artifacts.profileTemplates}|${patchedTemplates}|g' \
              ${artifacts.seedProfiles}/bin/dsh-sync-profiles > "$out/bin/dsh-sync-profiles"
            chmod +x "$out/bin/dsh-sync-profiles"
            if grep -Fq ${lib.escapeShellArg artifacts.profileTemplates} "$out/bin/dsh-sync-profiles"; then
              echo "dsh: patched seeder still references the unpatched templates" >&2
              exit 1
            fi
          '';
    in
    artifacts
    // {
      profileTemplates = patchedTemplates;
      seedProfiles = patchedSeeder;
    };
in
{
  imports = [ deepseek-harness.nixosModules.default ];

  options.modules.dsh = {
    enable = lib.mkEnableOption "DeepSeek Harness (dsh)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # pkgs.dsh.dsh-desktop

      # wrapper 也指向 fork 构建（passthru.unwrapped）
      (nur-DataEraserC.packages.${pkgs.system}.qq-bridge.override {
        unwrapped = qqBridgeForkUnwrapped;
      })
      nur-DataEraserC.packages.${pkgs.system}.dsh-plugin-guard
      # modlens is declared as a dsh bundle above and ships inside dsh's own
      # closure, but neither path links its bin into PATH, so `modlens` was
      # not runnable from a shell (the dsh tool calls it by absolute store
      # path, which is why modlens_read_image worked anyway). Adding it here
      # exposes the CLI for manual `doctor` / `config set` / `analyze` use.
      modlensPatched
    ];

    # browser4（MCP 驱动的浏览器自动化）经 modules.browser4 →
    # programs.dataEraserc.browser4 进 PATH：包装层自带 store runtime、
    # 自动建日志目录、拦截 BROWSER4_RUNTIME_DIR 覆盖（详见 nur 包 AGENTS.md）。
    # 后端不是 systemd 服务，长驻请用 harness 后台任务；Chrome 路径用
    # modules.browser4.browserPath 单独配置。
    modules.browser4.enable = lib.mkDefault true;

    programs.dsh = {
      enable = true;

      # 把补过 dependencies 的模板接进 nix 同步链（bin/dsh → dsh-seed-profile →
      # dsh-sync-profiles，模板集合路径烤死在 seeder 脚本里）。mkDsh 只认
      # `package.override`，所以用上游给 split integrations 留的 profileSeeder
      # 插槽整只换掉 seeder；profileDefaultProfile 顶替原来 validatedDefaultProfile
      # 提供的无参默认 profile（行为逐字不变）。再包一层 passthru，desktop/HM
      # 将来启用时经 mkProfileArtifacts 拿到的也是补过的模板。base 用
      # pkgs.dsh.dsh：它就是 mkPackageOption 的默认值（override 链会保留
      # profileSeeder 参数）。
      package =
        let
          artifacts = pkgs.dsh.dsh.passthru.mkProfileArtifacts {
            inherit (config.programs.dsh) profiles agentPresets defaultProfile;
            desktopProfile =
              if config.programs.dsh.desktop.enable then config.programs.dsh.desktop.profile else null;
            homePatch = config.programs.dsh.patch;
          };
          patched = patchProfileDeps artifacts;
          base = pkgs.dsh.dsh.override (_: {
            profileSeeder = patched.seedProfiles;
            profileDefaultProfile = config.programs.dsh.defaultProfile;
          });
        in
        base
        // {
          passthru = (base.passthru or { }) // {
            mkProfileArtifacts = args: patchProfileDeps (base.passthru.mkProfileArtifacts args);
            profileTemplates = patched.profileTemplates;
            seedProfiles = patched.seedProfiles;
          };
        };

      # Home-level layer (`$DSH_HOME/cordis.patch.yml`): dsh 0.1.7 applies it
      # as "machine-local preferences that apply to every profile"
      # (profile-boot), below the profile layers. The rows used to be
      # declared here (the two Settings rows plus the model catalog from
      # dsh-model-patch.json); they now live verbatim in the repo file
      # `modules/nixos/base/custom/dsh/common.yml`, which activation
      # symlinks to `$DSH_HOME/cordis.patch.yml` (see below).
      #
      # Leaving `patch` null is load-bearing, not an omission: the seed
      # wrapper copies the home file only when a home patch is declared
      # (`homePatchFile != null`), so null is what lets that symlink survive
      # every launch untouched. To change the rows, edit the repo file and
      # rebuild/switch; the rows hold only `apiKeyEnv` references, never key
      # material (values stay in `$DSH_HOME/.credentials.yaml`, mode 600).
      patch = null;

      # Each profile's patch layer is its repo yml (`repoPatch`); the four
      # LAN profiles merge `webLanPatch` ahead of the git rows (see
      # `mergeWebLan` above).
      profiles = {
        # Full profiles: entry + shared base + shared extras.
        tui = {
          bundles = tuiBundles;
          patch = repoPatch "tui";
        };
        web = {
          bundles = webBundles;
          patch = repoPatch "web";
        };

        # Minimal fallback for the plain surfaces: entry + shared base only.
        #   dsh --profile nix-tui-failsafe
        #   dsh --profile nix-web-failsafe
        tui-failsafe = {
          bundles = tuiFailsafeBundles;
          patch = repoPatch "tui-failsafe";
        };
        web-failsafe = {
          bundles = webFailsafeBundles;
          patch = repoPatch "web-failsafe";
        };

        # Group-chat combos: full = the whole web stack + the QQ stack, so
        # one instance serves both the web and the qq use; the failsafe drops
        # only the shared extras (the former `web-qq` composition).
        #   dsh --profile nix-web-qq
        #   dsh --profile nix-web-qq-failsafe
        web-qq = {
          bundles = webQQBundles;
          patch = repoPatch "web-qq";
        };
        web-qq-failsafe = {
          bundles = webQQFailsafeBundles;
          patch = repoPatch "web-qq-failsafe";
        };

        # The same composition as `web`, with the webserver row patched to
        # bind every interface (see `webLanPatch` above):
        #   dsh --profile nix-web-lan --no-open
        web-lan = {
          bundles = webBundles;
          patch = mergeWebLan (repoPatch "web-lan") webLanPatch;
        };
        web-lan-failsafe = {
          bundles = webFailsafeBundles;
          patch = mergeWebLan (repoPatch "web-lan-failsafe") webLanPatch;
        };

        # The two qq combos with the same LAN webserver patch — deliberate
        # starts, like `web-lan`:
        #   dsh --profile nix-web-qq-lan --no-open
        #   dsh --profile nix-web-qq-lan-failsafe --no-open
        web-qq-lan = {
          bundles = webQQBundles;
          patch = mergeWebLan (repoPatch "web-qq-lan") webLanPatch;
        };
        web-qq-lan-failsafe = {
          bundles = webQQFailsafeBundles;
          patch = mergeWebLan (repoPatch "web-qq-lan-failsafe") webLanPatch;
        };
      };
      defaultProfile = config.programs.dsh.profiles.tui.materializedName;
    };

    # Keep the home patch on a leash instead of a copy: activation symlinks
    # `$DSH_HOME/cordis.patch.yml` at the repo file above (out-of-store when
    # the configPath pool is set, a store copy otherwise). With
    # `programs.dsh.patch = null` the seed wrapper neither validates nor
    # copies that path — its `validate_owned_file` would die on a symlink —
    # so the link survives every `dsh` launch, while the boot loader follows
    # it with a plain YAML read (comments allowed) and applies the rows.
    system.activationScripts.dsh-cordis-patch = {
      deps = [ "users" ];
      text = ''
        dshHome="/home/${myvars.username}/.dsh"
        if [ ! -d "$dshHome" ]; then
          install -d -m 755 -o ${myvars.username} -g users "$dshHome"
        fi
        ln -sfnT ${mylib.mklinkRelativeToRoot config "modules/nixos/base/custom/dsh/common.yml"} "$dshHome/cordis.patch.yml"
      '';
    };

    # QQ presets (qq-chat / qq-chat-v2) now ship with the qq-bridge-dsh
    # bundle: nur generates the `@deepseek-ai/dsh-agent-preset` declarations
    # at build time (generate-preset-rows.py), so the old activation script
    # that copied files into ~/.dsh/.agent-presets is gone — dsh 0.1.7's
    # registry never scanned that directory anyway.
  };
}
