{
  pkgs,
  deepseek-harness,
  nur-DataEraserC,
  # qq-bridge fork 源码的 path input（详见 flake.nix 的 qq-bridge-fork）
  qq-bridge-fork,
  acb,
  config,
  myvars,
  lib,
  mylib,
  ...
}:
let
  cfg = config.modules.dsh;

  # fork 同步三件套（每次 git merge 上游后按序核对）：
  #   1. flake.lock 的 qq-bridge-fork narHash（nix flake update qq-bridge-fork）；
  #   2. qqBridgeVersion ← fork package.json 的 version；
  #   3. qqBridgeNpmDepsHash ← fork package-lock.json（FOD 不匹配时错误里的
  #      "got: sha256-..." 即新值）。
  qqBridgeVersion = "0.2.0-r4";
  qqBridgeNpmDepsHash = "sha256-0J+novef8zIp5xyFumglORObBtWJHBZ8PhY3v7Irhyg=";

  # 用 fork（flake input qq-bridge-fork）覆盖 qq-bridge-unwrapped 的 src，再喂给
  # 下面三处 .override 的 unwrapped 参数，让 bridge 服务、DSH MCP servers、
  # agent presets 三件套都跑 fork 代码（master-downstream：上游 0.2.0-r4 合并 +
  # 下游扩展，含工具 qq_get_message_media）。刻意用 overrideAttrs 而不是改 nur
  # 侧的 default.nix：qq-bridge-unwrapped 文件与上游保持逐字一致，nix-update /
  # 自动更新不受影响。
  qqBridgeSrc = builtins.path {
    path = qq-bridge-fork;
    # 解包目录必须叫 source：buildDshBundle 的 sourceRoot 写死
    # "source/plugins/..."，而目录型 src 是按 store 名字拷出来的
    # （fetchFromGitHub 的 tarball 解包后也是 source）。
    name = "source";
    # 不把 .git 与依赖目录带进 store（运行时 node_modules 由构建期 npm 流水线生成）。
    filter =
      path: _type:
      let
        base = baseNameOf path;
      in
      base != "node_modules" && base != ".git";
  };

  # npmDeps 必须连 hash 一起显式覆写：nixpkgs extendMkDerivation 在 overrideAttrs
  # 合并之前就把 npmDeps 物化进派生，只改 npmDepsHash 属性会得到「新哈希、旧依赖」
  # 的错配（npmConfigHook 随即报 package-lock.json 不一致）。src 与 lock 同源，
  # 与 npmConfigHook 的对账天然一致；fetcherVersion 与 buildNpmPackage 默认的
  # NIX_NPM_FETCHER_VERSION=1 保持相等。
  qqBridgeForkNpmDeps = pkgs.fetchNpmDeps {
    src = qqBridgeSrc;
    name = "qq-bridge-unwrapped-${qqBridgeVersion}-npm-deps";
    hash = qqBridgeNpmDepsHash;
    fetcherVersion = 1;
  };

  qqBridgeForkUnwrapped =
    nur-DataEraserC.packages.${pkgs.system}.qq-bridge-unwrapped.overrideAttrs
      (_: {
        src = qqBridgeSrc;
        name = "qq-bridge-unwrapped-${qqBridgeVersion}";
        version = qqBridgeVersion;
        npmDepsHash = qqBridgeNpmDepsHash;
        npmDeps = qqBridgeForkNpmDeps;
      });

  # PATH 里的 qq-bridge 是两层：本层先把 store 树同步进可写的 QQ_BRIDGE_HOME，
  # 再 exec nur 侧 wrapper（数据目录、config 播种、exec node 仍归它管）。nur 的
  # wrapper 只在「package.json 不存在」时拷一次，升级后 home 里还是旧代码：
  # 0.2.0-r3 那次 DSH 的 MCP servers 跑 store 新码、bridge 跑 home 里的 0.1.7，
  # 两个 send 工具在旧代码里根本没有路由，于是全部 `not found`。同步逻辑放这儿
  # 而不是改 nur 的 default.nix —— 上游 wrapper 逐字不动，也不匹配它的脚本文本
  # （它改脚本这里不会跟着坏）。config.json 与 state/ 只存在于 home、store 树里
  # 没有，cp 覆盖不到它们。
  #
  # 判据是 store 路径而不是 package.json 的 version：store 路径由内容决定，内容
  # 一变就变，连「改了 fork 但忘了 bump qqBridgeVersion」也一并抓到（version 比对
  # 会漏这种）。戳记写在 home 里，跟着数据目录一起被 impermanence 保留。
  qqBridgeLauncher =
    let
      nurWrapper = nur-DataEraserC.packages.${pkgs.system}.qq-bridge.override {
        unwrapped = qqBridgeForkUnwrapped;
      };
    in
    pkgs.writeShellScriptBin "qq-bridge" ''
      set -e

      export PATH="${lib.makeBinPath [ pkgs.coreutils ]}:$PATH"

      # 数据目录解析顺序与 nur wrapper 保持一致，两层必须指向同一目录。
      QQ_BRIDGE_HOME="''${QQ_BRIDGE_HOME:-''${XDG_DATA_HOME:-$HOME/.local/share}/qq-bridge}"
      storeTree=${qqBridgeForkUnwrapped}/lib/node_modules/qq-bridge
      stamp="$QQ_BRIDGE_HOME/.nix-store-tree"

      mkdir -p "$QQ_BRIDGE_HOME"

      if [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$storeTree" ]; then
        cp -r "$storeTree"/* "$QQ_BRIDGE_HOME/"
        chmod -R u+w "$QQ_BRIDGE_HOME"
        printf '%s\n' "$storeTree" > "$stamp"
      fi

      exec ${nurWrapper}/bin/qq-bridge "$@"
    '';

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
  # `master-patches-fix` (rev pinned below) is now a true MERGE of upstream
  # master with our IP-pool line — both histories stay reachable, future
  # upstream syncs are ordinary merges, and GitHub shows 0 behind. Two syncs
  # so far: 0.3.11 (upstream 235bcb4) and the #59-#66 batch (upstream
  # 8ccc3f8). The first two picks below (#14, #23) were adopted upstream
  # during the first sync (1f270f4 / 36e83bb), and the session-id fix during
  # the second — upstream fixed #62 itself with the same algorithm — so the
  # content delta against upstream is the pool line plus the inference-surface
  # fix recorded last below; the commits in order:
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
  #  - OpenCode session-id time field (Assisted-by trailer): #62 reported a
  #    permanent 403 on the free lane. The derived `ses_` id took its 12 hex
  #    characters from a sha256 digest, but OpenCode's identifier.create()
  #    stamps the low 48 bits of ~((Date.now()*0x1000) + counter) into that
  #    field and the lane rejects a session id without a plausible timestamp.
  #    The prefix is minted OpenCode's way now, memoized per digest so ids
  #    stay stable across turns, and the free-tier error is classified ahead
  #    of the 401/403 AUTH branch so DSH reports the real cause instead of
  #    "invalid API key".
  #
  #    Superseded by upstream in the second sync: upstream fixed #62 itself
  #    (PR #65, 79f01a5) with the identical algorithm, so the fork takes
  #    upstream's files wholesale — src/adapter/{ids,events}.ts and both test
  #    files are byte-identical to upstream, and the label is upstream's
  #    FREE_TIER_RESTRICTED. No part of that fix is still ours.
  #
  #  - Free-lane inference surface (Assisted-by trailer, refs
  #    Ebony-Vinyl/dsh-our-free-model#310): the anonymous lane moved from
  #    /zen to /inference and added an agent-shape gate. Four independent
  #    refusals, each fatal alone: a non-empty `x-opencode-request` header, a
  #    `prj_*` project id, a gate tool advertising an empty parameter object,
  #    and the old base URL. The adapter now points at
  #    https://opencode.ai/inference, drops that header, sends project
  #    `global`, and gates on the official `read` tool definition. Ablated
  #    one at a time: each alone still 403s, all four together 200. Model
  #    lists answered 200 on both surfaces with the same 85 ids, which is why
  #    it read as a key problem while every conversation was refused.
  #
  # The first two commits keep their upstream author/message; the later ones
  # are ours. Rebase the fork branch onto the next upstream tag when
  # nur-DataEraserC catches up, then drop this override entirely. `patches = [ ]`
  # clears whatever upstream adds later, so only the pinned tree ships.
  opencode2dsh = nur-DataEraserC.packages.${pkgs.system}.opencode2dsh.overrideAttrs (
    old:
    let
      # c91dcae = 691e8ed + the second upstream sync merge (upstream master
      # through the #59-#66 batch, 8ccc3f8) + the free-lane inference-surface
      # fix (refs #310, detailed above). The sync carries upstream's own fix
      # for #62 (PR #65, identical algorithm), which replaced ours, so the
      # fork's content delta against upstream is the IP-pool line plus the
      # inference-surface fix. No dependency changes: the pnpmDeps
      # fixed-output hash is unchanged (lockfile byte-identical to 691e8ed).
      forkSrc = pkgs.fetchFromGitHub {
        owner = "DataEraserC";
        repo = "opencode2dsh";
        rev = "c91dcae532a5a388cd9ac3a026763aa1ed67a5b7";
        hash = "sha256-nj8n4Y2b1olJBwvEHa2+JbB8ABUyDBbwqZea0R/Bd6o=";
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
  defaultTuiEntry = [ pkgs.dsh.bundles.tui ];
  defaultWebEntry = [
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
  # Web search is built in as of the harness migration (DeepSeek Search API by
  # default; see the upstream migration guide), so bundles.modsearch was
  # removed and must not be selected.
  defaultBaseBundles = [
    pkgs.dsh.bundles.remote
  ];

  # Extras shared by the full `tui` and `web` profiles: optional plugins
  # layered on top of the base. Later bundles override earlier Cordis
  # configuration, so keep risky additions here — the failsafe profiles
  # omit this list entirely. The unstable QQ stack lives in `qqBundles`
  # below and ships only in the `web-qq*` profiles.
  defaultExtraBundles = [
    # Snapshot the profile patch document and replay Settings-UI edits that
    # dsh-sync-profiles reverts on managed profiles: restores happen only
    # while the .nix-managed fingerprint still matches, so a `just local`
    # nix change still wins. Headless and zero-dependency, but kept out of
    # the *-failsafe profiles so the escape hatch stays a pure baseline.
    nur-DataEraserC.packages.${pkgs.system}.dsh-settings-persist
    nur-DataEraserC.packages.${pkgs.system}.dsh-turn-rewind
    # Retired: cliproxyapi is no longer deployed.
    # pkgs.dsh.bundles.cpa
    # dsh.nix pins 0.1.21 (peer ranges stop before DSH 0.2.0-rc.2); the nur package
    # carries upstream's fixed 0.1.22. Drop back once deepseek-harness.nix catches up.
    # nur-DataEraserC.packages.${pkgs.system}.dsh-agent-teams
    # pkgs.dsh.bundles.ads
    # Archived: dsh ships a built-in navbar implementation now.
    # pkgs.dsh.bundles.navbar
    opencode2dsh
    nur-DataEraserC.packages.${pkgs.system}.bas-remote
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
    # Share selected conversations as PNG images or Markdown text. Its cordis
    # patch is a single insert row (id dsh-share) so it never overrides another
    # bundle's rows; the browser half rides package.json dsh.client (web only,
    # hence passthru.requiresWeb) and the server half has no runtime deps of its
    # own — its package node_modules links straight into the kernel.
    nur-DataEraserC.packages.${pkgs.system}.dsh-share
    # Chrome-driven browser automation (ego_* tools). runtimeDeps pins
    # google-chrome onto the dsh launcher PATH so auto-detect works even when
    # dsh starts without the user profile PATH; chromePath / EGO_LINUX_CHROME
    # remain the manual override. The optional sidebar partner
    # pkgs.dsh.bundles.better-sidebar stays off — the floating observe ball
    # is the fallback.
    nur-DataEraserC.packages.${pkgs.system}.dsh-ego-browser
    # # Isolated virtual X display for GUI automation and games (iso_display_*
    # # tools + web panel): Xvfb by default, sway/Xwayland when sway is present
    # # (DRI3 → Vulkan/GL passthrough), VNC pop-out on demand, and a per-display
    # # PulseAudio null sink so nothing is heard. runtimeDeps pins every backend
    # # binary (Xvfb, sway, Xwayland, grim, xdotool, ImageMagick, x11vnc,
    # # tigervnc's vncviewer, wayvnc, procps, pactl) onto the dsh launcher PATH —
    # # the plugin only resolves them by name. Linux-only; the sway backend also
    # # needs the user in `render` to open /dev/dri/renderD*. Deliberately NOT in
    # # the qq-agent-presets allow list: iso_display_run is arbitrary command
    # # execution, so the group-chat surface keeps it hidden while web/tui
    # # sessions see the full tool set.
    # nur-DataEraserC.packages.${pkgs.system}.dsh-headless-display
    # Local-desktop computer use (`mcp__cua-driver-mcp__*`) is DISABLED — see
    # DS-012 in WORKAROUNDS_downstream.md. The spawned `cua-driver mcp`
    # advertises itself as a screen reader at startup, which flips
    # `org.a11y.Status.IsEnabled` and makes GNOME launch Orca on this host for
    # as long as dsh runs. The bundle also pinned the Nix-built cua-driver
    # onto the dsh launcher PATH and its version-matched skill pack into
    # `$DSH_HOME/skills/cua-driver` (activation script below); both are off
    # together, so re-enabling means restoring this line AND that link.
    # Sandboxed desktop control (`dsh-cua-sandbox` below) is unaffected and
    # keeps the `mcp__cua-mcp__*` tool surface.
    # nur-DataEraserC.packages.${pkgs.system}.dsh-cua-driver
    # Sandboxed desktop control through the `cua` CLI's MCP server: the model
    # gets mcp__cua-mcp__* tools — sandbox_* lifecycle (create / list / get /
    # start / stop / restart / suspend / delete / view / vnc / open_browser)
    # plus computer_* desktop control (screenshot, click, type, key, shell,
    # file IO, windows, accessibility) with the target sandbox named per call.
    # Every call lands inside a container "computer" run by cua-vmm (Podman /
    # Docker + gVisor/runc, QEMU, Lume) — NOT this machine's session. With the
    # local-desktop driver above disabled this is the only desktop-control
    # surface, so a risky experiment gets a disposable sandbox instead of the
    # user's session. The bundle inserts the
    # kernel's own mcp-client plugin (no wrapper JS, no pinned hashes — the
    # pair is version-matched to the kernel by construction) and pins the
    # Nix-built cua-cli onto the launcher PATH for `command: cua`. `cua mcp`
    # starts without the engine, so a missing Podman socket only fails
    # individual calls; Podman plus the rootless engine socket are enabled at
    # the bottom of this module, and the matching skills are linked into
    # $DSH_HOME/skills by the dsh-home activation script below.
    nur-DataEraserC.packages.${pkgs.system}.dsh-cua-sandbox
    # Zero-setup free-model roster: the bundle's cordis patch is a single
    # insert row (id our-free-model), so it never overrides another bundle's
    # rows and order here is irrelevant; the browser half rides the
    # package.json dsh.client declaration. Egress runs through the mihomo
    # binary from its runtimeDeps — no PATH wiring needed at this layer.
    # extraWebProfiles unlocks the sealed EAC lane: src/vault.js admits only
    # the profile names `web`/`web-desktop`/`desktop`, so every custom web
    # profile would render a dark lane and never load the EAC roster. List
    # the profiles that both load this bundle and can show its client half —
    # the *-failsafe ones carry no extras at all, and tui has no web UI.
    (nur-DataEraserC.packages.${pkgs.system}.dsh-our-free-model.override {
      extraWebProfiles = [
        "nix-web"
        "nix-web-lan"
        "nix-web-qq"
        "nix-web-qq-lan"
        "nix-web-acb"
      ];
    })
    # Free web search with smart engine routing (ddg/bing/searxng… plus a
    # keyless fallback) and a settings UI. The browser half rides the
    # package.json dsh.client declaration (web profiles, hence passthru.requiresWeb)
    # and the server half links its node_modules straight into the kernel.
    nur-DataEraserC.packages.${pkgs.system}.dsh-free-search
    # Content extraction, not just video: per-platform extractors for video
    # (yt-dlp + ffmpeg compression to QQ-sendable size), bilibili articles and
    # opus posts, 完美世界电竞 community posts, 吉星派对 match replays and direct
    # files. The caller picks the extractor — content_candidates lists who could
    # handle a URL, content_extractor runs the chosen one — because one host
    # serves many content kinds and guessing would send an article down the
    # video path. Per-site login (bilibili QR / cookie import) raises quality
    # and unlocks gated content for every extractor that benefits, not only
    # video. Server-only — no dsh.client half, so tui and web profiles both get
    # it. yt-dlp/ffmpeg arrive via the package's own runtimeDeps, no PATH wiring
    # needed here.
    nur-DataEraserC.packages.${pkgs.system}.dsh-content-extractor
    # Drive the local ComfyUI (image / video / audio generation) with the whole
    # workflow adjustable from the dsh side: parameter snapshots per saved
    # workflow plus user-added advanced parameters covering any node input,
    # including custom nodes. Web-only client half (panels), hence
    # passthru.requiresWeb; the server half talks to the ComfyUI HTTP endpoint
    # and carries no runtime deps of its own.
    nur-DataEraserC.packages.${pkgs.system}.dsh-comfyui
    pkgs.dsh.bundles.harbor
    # Context insight and management: a first-level insights page, the Context
    # and Fleet session tabs, a right-sidebar panel and the `/context` command.
    # Its cordis patch is a single insert row (id dsh-context), so order here is
    # irrelevant; the browser half rides package.json dsh.client, hence
    # passthru.requiresWeb, and its peer ranges accept the pinned 0.2.2 kernel.
    pkgs.dsh.bundles.context
    # graph-memory and notification were removed from the repository (see the
    # upstream migration guide); use bundles.mneme/mnemon for cross-session
    # memory.
    # Official experimental plugins, declared so the WebUI switch is durable:
    # the switch only edits the profile package.json's dsh.profile.bundles,
    # which dsh-sync-profiles reverts on every launch — the "reset after
    # restart" bug. In the template they ship enabled and the fingerprint
    # stays self-consistent. extraBundles is the intended home: every full
    # profile (tui/web/web-lan/web-qq/web-qq-lan) carries it and every
    # *-failsafe drops it, so the escape hatch stays a pure baseline.
    # agent-team-profile layers last on purpose — its patch replaces the
    # subagent tool rows and must apply after dsh-base ("Apply after
    # dsh-base" in its cordis.patch.yml); it is requiresWeb, but so is the
    # rest of this list (baseBundles' modsearch/remote already force
    # needsWeb on every profile including tui).
    pkgs.dsh.bundles.experimental-session-search
    pkgs.dsh.bundles.experimental-session-titles-bundle
    pkgs.dsh.bundles.experimental-tool-worktree
    # experimental-agent-team-profile was removed in 0.2.2-rc.2: enable Team
    # per session in the built-in interface instead.
    pkgs.dsh.bundles.experimental-auto-review
  ];

  # QQ group-chat stack: unstable, so it stays out of the plain profiles and
  # ships only in the `web-qq*` combos — layered after `extraBundles` in the
  # full combo, used in place of them in the failsafe combos. Group chat
  # drives dsh through opencode2dsh, so the bridge pairs with it and needs
  # nothing beyond the shared entry and base.
  defaultQqBundles = [
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
        # dsh-content-extractor (7 tools). The generic pair first:
        # content_candidates lists every extractor that could handle a URL
        # (plural, advisory — it never picks), content_extractor runs the one
        # named. That two-step flow is deliberate: bilibili serves video,
        # articles and opus posts on one domain, so auto-selection would send
        # an article to the video path. Neither tool reaches the local shell;
        # output is confined to the session workspace.
        "content_candidates"
        "content_extractor"
        "content_extractors"
        # The video-specific trio plus settings: download with metadata, the
        # per-site login whose QR flow exists to be shown to the chat and
        # scanned there, compression to QQ-sendable size, and the settings tool
        # that edits the same profile patch the web card writes. Exact names;
        # cookie values never enter context and login import takes a path, not
        # file contents.
        "video_fetch"
        "video_login"
        "video_compress"
        "video_settings"
        # dsh-comfyui (4 tools): list/run the saved workflow library with its
        # per-run parameter overrides, hand-written API workflows for one-off
        # tests, node/model inspection, and the per-workflow skill pack. They
        # only reach the ComfyUI HTTP endpoint and the pack's own directory
        # (path containment), never the local shell — no restricted sibling.
        "comfyui_workflow"
        "comfyui_run"
        "comfyui_object_info"
        "comfyui_skill"
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
        # dsh-cua-sandbox's mcp__cua-mcp__* surface splits the same way the
        # ego_* pair did, but along a sharper line: INSIDE the disposable
        # sandbox vs OUTSIDE it. cua's MCP server registers 138 tools, not the
        # two families its cordis row advertises, and their reach is wildly
        # uneven — `space_bash`/`computer_shell` run in the container (harmless
        # there: `sandbox_create` itself takes an entrypoint command, so the
        # container is where arbitrary execution is by design), while
        # `teleport_*` imports the user's real browser cookies and
        # `volume_*`/`cloud_*` reach the account's persistent drive and billed
        # cloud accounts. Denying shell inside the sandbox would constrain
        # nothing and break the surface; admitting the rest would hand a group
        # chat the host's credentials through a different door.
        #
        # 45 allowed: sandbox lifecycle + the container's own desktop, files,
        # clipboard and shell. `sandbox_open_browser` is included because it is
        # the documented way to get a driven browser (a self-launched Chromium
        # cannot be attached); the throwaway-profile browser lives inside the
        # sandbox like everything else here.
        #
        # 93 denied — hidden from the schema AND rejected at execution (both
        # lists are consulted: restrict hides, guard rejects). Grouped by why:
        # sandbox 生命周期
        "mcp__cua-mcp__sandbox_create"
        "mcp__cua-mcp__sandbox_list"
        "mcp__cua-mcp__sandbox_get"
        "mcp__cua-mcp__sandbox_start"
        "mcp__cua-mcp__sandbox_stop"
        "mcp__cua-mcp__sandbox_restart"
        "mcp__cua-mcp__sandbox_suspend"
        "mcp__cua-mcp__sandbox_delete"
        "mcp__cua-mcp__sandbox_open_browser"
        # 镜像目录（挑镜像用）
        "mcp__cua-mcp__images_list"
        # 沙盒内执行与文件（沙盒是一次性容器，打不到宿主）
        "mcp__cua-mcp__computer_shell"
        "mcp__cua-mcp__computer_file_read"
        "mcp__cua-mcp__computer_file_write"
        "mcp__cua-mcp__computer_file_list"
        # 沙盒桌面控制
        "mcp__cua-mcp__computer_screenshot"
        "mcp__cua-mcp__computer_click"
        "mcp__cua-mcp__computer_double_click"
        "mcp__cua-mcp__computer_drag"
        "mcp__cua-mcp__computer_type"
        "mcp__cua-mcp__computer_key"
        "mcp__cua-mcp__computer_hotkey"
        "mcp__cua-mcp__computer_key_down"
        "mcp__cua-mcp__computer_key_up"
        "mcp__cua-mcp__computer_mouse_down"
        "mcp__cua-mcp__computer_mouse_up"
        "mcp__cua-mcp__computer_move_cursor"
        "mcp__cua-mcp__computer_scroll"
        "mcp__cua-mcp__computer_get_screen_size"
        "mcp__cua-mcp__computer_get_cursor_position"
        "mcp__cua-mcp__computer_get_current_window"
        "mcp__cua-mcp__computer_window_list"
        "mcp__cua-mcp__computer_window_get_info"
        "mcp__cua-mcp__computer_window_focus"
        "mcp__cua-mcp__computer_window_close"
        "mcp__cua-mcp__computer_window_move"
        "mcp__cua-mcp__computer_window_resize"
        "mcp__cua-mcp__computer_window_maximize"
        "mcp__cua-mcp__computer_window_minimize"
        "mcp__cua-mcp__computer_window_unfocus"
        "mcp__cua-mcp__computer_window_open"
        "mcp__cua-mcp__computer_launch"
        # 剪贴板与无障碍树
        "mcp__cua-mcp__computer_clipboard_get"
        "mcp__cua-mcp__computer_clipboard_set"
        "mcp__cua-mcp__computer_get_accessibility_tree"
        "mcp__cua-mcp__computer_accessibility_act"
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
        # 空间（Space）注册表与宿主侧入口（23）：cua 有两套注册表，
        # sandbox_create 建的容器在 sandbox_* 里，space_* 只认 add_space 注册的
        # Space —— 两侧互不可见（实测 space_bash 对 sandbox_create 的沙盒报
        # "Space not found"）。add_space 被拒 ⇒ space_bash/space_write 在这里
        # 什么也做不了，放行只会给模型一个永远失败的工具，故一并拒掉。
        "mcp__cua-mcp__add_space"
        "mcp__cua-mcp__space_bash"
        "mcp__cua-mcp__space_write"
        "mcp__cua-mcp__remove_space"
        "mcp__cua-mcp__create_space"
        "mcp__cua-mcp__delete_space"
        "mcp__cua-mcp__start_space"
        "mcp__cua-mcp__stop_space"
        "mcp__cua-mcp__list_spaces"
        "mcp__cua-mcp__list_space_windows"
        "mcp__cua-mcp__space_shares"
        "mcp__cua-mcp__stream_endpoint"
        "mcp__cua-mcp__stream_space_window"
        "mcp__cua-mcp__open_space_viewer"
        "mcp__cua-mcp__show_space_pip"
        "mcp__cua-mcp__hide_space_pip"
        "mcp__cua-mcp__send_file"
        "mcp__cua-mcp__upload"
        "mcp__cua-mcp__download"
        "mcp__cua-mcp__sandbox_view"
        "mcp__cua-mcp__sandbox_vnc"
        "mcp__cua-mcp__list_tools"
        "mcp__cua-mcp__call_tool"
        # 把本机凭据搬进沙盒（Cua Keyvault）（4）
        "mcp__cua-mcp__teleport_app"
        "mcp__cua-mcp__teleport_browser_session"
        "mcp__cua-mcp__teleport_manifest"
        "mcp__cua-mcp__request_site_login"
        # 持久卷 / 云端账单 / 别人的算力与网络（37）
        "mcp__cua-mcp__volume_approve"
        "mcp__cua-mcp__volume_audit"
        "mcp__cua-mcp__volume_cache_clear"
        "mcp__cua-mcp__volume_cache_set"
        "mcp__cua-mcp__volume_cache_stats"
        "mcp__cua-mcp__volume_delete"
        "mcp__cua-mcp__volume_deny"
        "mcp__cua-mcp__volume_grant"
        "mcp__cua-mcp__volume_grants"
        "mcp__cua-mcp__volume_history"
        "mcp__cua-mcp__volume_ls"
        "mcp__cua-mcp__volume_mount"
        "mcp__cua-mcp__volume_mount_status"
        "mcp__cua-mcp__volume_read"
        "mcp__cua-mcp__volume_request_access"
        "mcp__cua-mcp__volume_requests"
        "mcp__cua-mcp__volume_restore"
        "mcp__cua-mcp__volume_revoke"
        "mcp__cua-mcp__volume_storage"
        "mcp__cua-mcp__volume_storage_set"
        "mcp__cua-mcp__volume_sync_events"
        "mcp__cua-mcp__volume_sync_resolve"
        "mcp__cua-mcp__volume_sync_status"
        "mcp__cua-mcp__volume_unmount"
        "mcp__cua-mcp__volume_write"
        "mcp__cua-mcp__cloud_connect"
        "mcp__cua-mcp__cloud_disconnect"
        "mcp__cua-mcp__cloud_status"
        "mcp__cua-mcp__cloud_sweep"
        "mcp__cua-mcp__cloud_test"
        "mcp__cua-mcp__share_space"
        "mcp__cua-mcp__unshare_space"
        "mcp__cua-mcp__relay_register_space"
        "mcp__cua-mcp__relay_unregister_space"
        "mcp__cua-mcp__hotspot_start"
        "mcp__cua-mcp__hotspot_status"
        "mcp__cua-mcp__hotspot_stop"
        # 无人值守的自我调度与自我派生（19）
        "mcp__cua-mcp__agent_capabilities"
        "mcp__cua-mcp__agent_events"
        "mcp__cua-mcp__agent_interrupt"
        "mcp__cua-mcp__agent_list"
        "mcp__cua-mcp__agent_message"
        "mcp__cua-mcp__agent_pause"
        "mcp__cua-mcp__agent_resume"
        "mcp__cua-mcp__agent_start"
        "mcp__cua-mcp__agent_status"
        "mcp__cua-mcp__agent_stop"
        "mcp__cua-mcp__persistent_agent_create"
        "mcp__cua-mcp__persistent_agent_list"
        "mcp__cua-mcp__persistent_agent_remove"
        "mcp__cua-mcp__persistent_agent_save"
        "mcp__cua-mcp__persistent_agent_send"
        "mcp__cua-mcp__routine_add"
        "mcp__cua-mcp__routine_list"
        "mcp__cua-mcp__routine_remove"
        "mcp__cua-mcp__routine_set_enabled"
        # 用户的真机授权（这台机器的桌面/其他设备）（3）
        "mcp__cua-mcp__computer_access_grant"
        "mcp__cua-mcp__computer_access_list"
        "mcp__cua-mcp__computer_access_revoke"
        # 通知与技能库写入（7）
        "mcp__cua-mcp__notify_user"
        "mcp__cua-mcp__notifications_ack"
        "mcp__cua-mcp__notifications_list"
        "mcp__cua-mcp__skills_delete"
        "mcp__cua-mcp__skills_list"
        "mcp__cua-mcp__skills_read"
        "mcp__cua-mcp__skills_record"
      ];
      # presets 的 src 跟随 unwrapped.src
      unwrapped = qqBridgeForkUnwrapped;
    })
    # qq-mode-console 自己 callPackage 了一份 unwrapped（nur 上游 0.1.7），其
    # src / npmDepsHash / version 是在它自己的文件里求值期就绑定的，不随上面的
    # fork 覆写走 —— fork 同步时这里必须一起改，否则控制台跑旧代码、bundle 元
    # 数据却显示新版本。npmDeps 同样要显式覆写（见 qqBridgeForkNpmDeps 注释）。
    (nur-DataEraserC.packages.${pkgs.system}.qq-mode-console.overrideAttrs (_: {
      src = qqBridgeSrc;
      version = qqBridgeVersion;
      npmDepsHash = qqBridgeNpmDepsHash;
      npmDeps = qqBridgeForkNpmDeps;
    }))
  ];

  # 可写 bundle 集合的默认值见 modules.dsh.bundleSets；这里保留原引用名，
  # profile 组合继续从同一组 option 读取，避免出现两份清单。
  tuiEntry = cfg.bundleSets.tuiEntry;
  webEntry = cfg.bundleSets.webEntry;
  baseBundles = cfg.bundleSets.base;
  extraBundles = cfg.bundleSets.extra;
  qqBundles = cfg.bundleSets.qq;

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

  # ACB 的 preset bundle 随 ACB 仓库打包（nix/dsh-bundle）；这里只把部署侧的
  # 会话列表 override 进去。没有 ACB 会话时不加，避免给别的 host 塞空 bundle。
  acbBundle = acb.packages.${pkgs.system}.dsh-bundle.override {
    sessions = cfg.acbSessions;
  };
  webAcbBundles = webBundles ++ lib.optional (cfg.acbSessions != [ ]) acbBundle;

  # The LAN profiles deliberately declare NO webserver row. The web-app bundle
  # already ships one, whose bind host is the launcher provider:
  #
  #   host: !!js ctx.webStartup.host ?? '127.0.0.1'
  #
  # so `--host <concrete literal>` reaches the bind while the default stays
  # loopback:  dsh --profile nix-web-lan --host 10.126.126.150 --no-open
  #
  # Restating that row here would not be a harmless no-op: a patch assigns the
  # whole `config` object (`target[key] = value` in dsh-app-boot's
  # `applyEntryPatches`), never a deep merge, so a local restatement silently
  # drops every key it does not repeat — including `tls: !!js ctx.webStartup.tls`,
  # which disables `--tls-cert`/`--tls-key` without any error because the
  # schema defaults `tls` to undefined. It also freezes the row against every
  # key upstream adds later. (The row this replaced existed only to pin
  # `host: 0.0.0.0`, which is now rejected outright.)
  #
  # Nothing else could be pinned usefully either: `@deepseek-ai/dsh-host-webserver`
  # refuses unspecified addresses ("bind one concrete IPv4 or IPv6 address of a
  # local interface instead"), and the Nix build sandbox is a private network
  # namespace whose only interface is loopback (binding 192.168.1.8/192.168.5.100/
  # 10.147.20.150 there all fail), so no profile can pass `dshBundleCheckHook`
  # while default-binding a LAN address. LAN reachability is therefore a
  # launch-time decision plus the firewall: 3080 is not in `allowedTCPPorts`, so
  # only `trustedInterfaces` (tailscale0, zt5u4z6wb4, easytier0) reach it, and
  # the address must be one of this host's own
  # (`devices.y9000p2025.addrs.{easytier,tailscale,zerotier}.ip` in
  # vars/networking-downstream.nix) or the bind fails with EADDRNOTAVAIL. Only
  # the bound address enters dsh's browser-trust fence, so reaching the UI by
  # any other name needs an explicit `--trusted-host`.

  # Every profile's `cordis.patch.yml` rows come from the file
  # `<key>.yml` in this directory (dotfile-style: edit + prettier + `just local`).
  # Mode stays `managed`, so the profile file on disk is a store snapshot of
  # that repo file and is restored on the next launch — in-place edits never
  # persist by design.
  repoPatch = key: builtins.readFile (./${key}.yml);

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
        lib.unique (
          extraBundles ++ baseBundles ++ qqBundles ++ lib.optional (cfg.acbSessions != [ ]) acbBundle
        )
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

    acbSessions = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            id = lib.mkOption { type = lib.types.str; };
            preset = lib.mkOption { type = lib.types.str; };
            port = lib.mkOption { type = lib.types.port; };
          };
        }
      );
      default = [ ];
      description = "ACB 的 dsh 会话列表；每条生成一个 agent preset（preset 名 + 本地 MCP 端口）。";
    };

    bundleSets = {
      tuiEntry = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = defaultTuiEntry;
        description = "TUI profile 的入口 bundle 列表。";
      };
      webEntry = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = defaultWebEntry;
        description = "Web profile 的入口 bundle 列表。";
      };
      base = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = defaultBaseBundles;
        description = "所有 profile 共享的基础 bundle 列表。";
      };
      extra = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = defaultExtraBundles;
        description = "完整 tui/web profile 的额外 bundle 列表。";
      };
      qq = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = defaultQqBundles;
        description = "QQ 组合 profile 的 bundle 列表。";
      };
    };

    runtimePackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = config.programs.dsh.package.override {
        profiles = config.programs.dsh.profiles;
        agentPresets = config.programs.dsh.agentPresets;
        defaultProfile = config.programs.dsh.defaultProfile;
        desktopProfile =
          if config.programs.dsh.desktop.enable then config.programs.dsh.desktop.profile else null;
        homePatch = config.programs.dsh.patch;
      };
      description = ''
        上游 mkDsh 组合出的全量运行时包（服务/ACB 使用）。只读派生值；
        不得反向作为 profiles.*.bundles 或 patchProfileDeps 的输入。
      '';
    };

    profileTemplates = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = config.programs.dsh.package.passthru.profileTemplates;
      description = "经 patchProfileDeps 注入 dependencies 后的 profile 模板集合。";
    };

    seedProfiles = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = config.programs.dsh.package.passthru.seedProfiles;
      description = "指向上述模板集合的 dsh-sync-profiles seeder。";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # pkgs.dsh.dsh-desktop

      # qq-bridge：fork 构建 + store 同步的启动层（见 qqBridgeLauncher）
      qqBridgeLauncher
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
            # Newer harness revs assert that a replaced seeder carries the
            # bundleCheckProfiles from the mkProfileArtifacts call that built
            # it; without this the whole system evaluation throws
            # "dsh: profileSeeder requires profileBundleCheckProfiles".
            profileBundleCheckProfiles = patched.bundleCheckProfiles;
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
      # `modules/nixos/base/custom/ai/dsh/common.yml`, which activation
      # symlinks to `$DSH_HOME/cordis.patch.yml` (see below).
      #
      # Leaving `patch` null is load-bearing, not an omission: the seed
      # wrapper copies the home file only when a home patch is declared
      # (`homePatchFile != null`), so null is what lets that symlink survive
      # every launch untouched. To change the rows, edit the repo file and
      # rebuild/switch; the rows hold only `apiKeyEnv` references, never key
      # material (values stay in `$DSH_HOME/.credentials.yaml`, mode 600).
      patch = null;

      # Each profile's patch layer is exactly its repo yml (`repoPatch`) — no
      # profile injects rows from Nix. The `-lan` keys differ only in being the
      # deliberate-start LAN surfaces the user picks at launch.
      profiles = {
        # Full profiles: entry + shared base + shared extras.
        tui = {
          bundles = tuiBundles;
          patch = lib.mkDefault (repoPatch "tui");
        };
        web = {
          bundles = webBundles;
          patch = lib.mkDefault (repoPatch "web");
        };

        # Same composition as `web` (entry + base + extras, including
        # dsh-comfyui), but a separate key so the acb bridge can drive its
        # own surface without disturbing the plain web profile.
        #   dsh --profile nix-web-acb
        web-acb = {
          bundles = webAcbBundles;
          patch = lib.mkDefault (repoPatch "web-acb");
        };

        # Minimal fallback for the plain surfaces: entry + shared base only.
        #   dsh --profile nix-tui-failsafe
        #   dsh --profile nix-web-failsafe
        tui-failsafe = {
          bundles = tuiFailsafeBundles;
          patch = lib.mkDefault (repoPatch "tui-failsafe");
        };
        web-failsafe = {
          bundles = webFailsafeBundles;
          patch = lib.mkDefault (repoPatch "web-failsafe");
        };

        # Group-chat combos: full = the whole web stack + the QQ stack, so
        # one instance serves both the web and the qq use; the failsafe drops
        # only the shared extras (the former `web-qq` composition).
        #   dsh --profile nix-web-qq
        #   dsh --profile nix-web-qq-failsafe
        web-qq = {
          bundles = webQQBundles;
          patch = lib.mkDefault (repoPatch "web-qq");
        };
        web-qq-failsafe = {
          bundles = webQQFailsafeBundles;
          patch = lib.mkDefault (repoPatch "web-qq-failsafe");
        };

        # The same composition as `web`; these are the profiles to launch when
        # the UI must answer on an overlay address — pass it explicitly, since
        # an unspecified (wildcard) bind is rejected by dsh 0.2.1-alpha.2:
        #   dsh --profile nix-web-lan --host 10.126.126.150 --no-open
        web-lan = {
          bundles = webBundles;
          patch = lib.mkDefault (repoPatch "web-lan");
        };
        web-lan-failsafe = {
          bundles = webFailsafeBundles;
          patch = lib.mkDefault (repoPatch "web-lan-failsafe");
        };

        # The two qq combos on the same seam — deliberate starts, like
        # `web-lan`, and reachable only with an explicit `--host`:
        #   dsh --profile nix-web-qq-lan --host 10.126.126.150 --no-open
        #   dsh --profile nix-web-qq-lan-failsafe --host 10.126.126.150 --no-open
        web-qq-lan = {
          bundles = webQQBundles;
          patch = lib.mkDefault (repoPatch "web-qq-lan");
        };
        web-qq-lan-failsafe = {
          bundles = webQQFailsafeBundles;
          patch = lib.mkDefault (repoPatch "web-qq-lan-failsafe");
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
    #
    # The same script owns the rest of the Nix-managed entries under
    # `$DSH_HOME`: `skills/` is dsh's user-level skill root (rank 400 in the
    # skill-filesystem provider) and today holds only the cua sandbox skills.
    # The cua-driver skill pack that used to live there is gone with its
    # bundle (DS-012). The home-side agent config (rules, cross-tool skills,
    # agent CLIs) deliberately stays in home/base/tui/agents; only $DSH_HOME
    # itself is laid out here.
    system.activationScripts.dsh-home = {
      deps = [ "users" ];
      text = ''
        dshHome="/home/${myvars.username}/.dsh"
        if [ ! -d "$dshHome" ]; then
          install -d -m 755 -o ${myvars.username} -g users "$dshHome"
        fi
        ln -sfnT ${mylib.mklinkRelativeToRoot config "modules/nixos/base/custom/ai/dsh/common.yml"} "$dshHome/cordis.patch.yml"

        install -d -m 755 -o ${myvars.username} -g users "$dshHome/skills"

        # The local-desktop skill pack is DISABLED with its bundle (DS-012).
        # Drop the link an earlier generation left behind — activation never
        # cleans $DSH_HOME on its own, so without this the disabled surface
        # would linger until gc. `-L` keeps a real directory a user put there.
        if [ -L "$dshHome/skills/cua-driver" ]; then
          rm -f "$dshHome/skills/cua-driver"
        fi

        # cua sandbox skills for the mcp__cua-mcp__* surface (dsh-cua-sandbox):
        # the workflow knowledge the MCP tool list cannot carry — how to pick
        # an image, create a sandbox, wait for boot, then drive it. Same
        # package the bundle pins onto the launcher PATH, so the `cua` CLI
        # examples in the skill resolve inside dsh. Upstream's own
        # `cua skills install` agent list has no dsh entry, hence the manual
        # links.
        ln -sfnT ${
          nur-DataEraserC.packages.${pkgs.system}.cua-cli
        }/share/cua-skills/cua-sandboxes "$dshHome/skills/cua-sandboxes"
        ln -sfnT ${
          nur-DataEraserC.packages.${pkgs.system}.cua-cli
        }/share/cua-skills/gui-automation "$dshHome/skills/gui-automation"
      '';
    };

    # Container engine for the cua sandbox surface (dsh-cua-sandbox above):
    # cua-vmm talks to Podman over the rootless docker-compatible API socket
    # at $XDG_RUNTIME_DIR/podman/podman.sock. nixpkgs already delivers that:
    # virtualisation.podman installs the package's OWN user units through
    # `systemd.packages = [ cfg.package ]` — podman.socket listens on
    # %t/podman/podman.sock and podman.service runs `podman system service`,
    # which discovers that socket through systemd socket activation
    # (LISTEN_FDS), so nothing idles until a `cua mcp` tool call connects —
    # and enables it with `systemd.user.sockets.podman.wantedBy =
    # [ "sockets.target" ]`. Subordinate uid/gid ranges are auto-allocated
    # for normal users (autoSubUidGidRange), which is all rootless podman
    # needs.
    #
    # Do NOT redeclare those two units here. Both the package unit and the
    # NixOS-generated drop-in carry an `ExecStart=`, and systemd rejects a
    # service that ends up with two ("more than one ExecStart= setting,
    # which is only allowed for Type=oneshot services"), which is exactly
    # how the earlier hand-written pair killed the socket at boot. Only the
    # enable flag belongs in this module.
    #
    # A host that must not run containers overrides this with
    # `lib.mkForce false` — dsh still starts, the sandbox tools are present
    # and each call fails on its own.
    virtualisation.podman.enable = lib.mkDefault true;

    # QQ presets (qq-chat / qq-chat-v2) now ship with the qq-bridge-dsh
    # bundle: nur generates the `@deepseek-ai/dsh-agent-preset` declarations
    # at build time (generate-preset-rows.py), so the old activation script
    # that copied files into ~/.dsh/.agent-presets is gone — dsh 0.1.7's
    # registry never scanned that directory anyway.
  };
}
