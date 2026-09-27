{
  pkgs,
  deepseek-harness,
  nur-DataEraserC,
  config,
  myvars,
  lib,
  ...
}:
let
  cfg = config.modules.dsh;

  # Temporary fixes for FishBottle7/opencode2dsh, applied on top of the v0.3.2
  # that nur-DataEraserC pins (both PRs were still open upstream at the time of
  # writing; both patches are regenerated against v0.3.2 with paths relative to
  # sourceRoot source/packages/plugin). Drop each patch once nur-DataEraserC
  # ships a release containing its fix.
  #
  #  - opencode2dsh#14: ZenAdapter never implements imageRequestPricing(), so
  #    dsh-llm's pricing lookup throws "TypeError: this.adapters.get(...)?.
  #    adapter.imageRequestPricing is not a function" on every /compact
  #    (manual or automatic).
  #
  #  - opencode2dsh#23 (dsh-017): DSH 0.1.7 removed the client's
  #    `settingsScope` service and the keyed `settings.plugin.item` slot, but
  #    the plugin still listed them as fiber dependencies — the web surface
  #    parked the whole plugin at
  #      pending (waiting for service: settingsScope)
  #    so the IP 池 settings card never appeared and the plugin never
  #    activated. The patch moves the client onto `configForms` +
  #    the `plugins.item` slot, exports `Config` with a volatile `ipPool` node
  #    (replacing `ctx.settings.register()`), and rewrites
  #    `dsh.client.inject` to package-row tokens. It also re-resolves the
  #    workspace dependencies: schemastery ≥ 3.18.4 is REQUIRED at runtime
  #    because `IpPoolConfigSchema.volatile()` does not exist in 3.18.1, so
  #    pnpm-lock.yaml changes and the fixed-output pnpmDeps must be refetched
  #    against the patched lockfile (the patch is applied inside sourceRoot of
  #    that fetch too) — hence the pnpmDeps override with the recomputed hash.
  opencode2dsh = nur-DataEraserC.packages.${pkgs.system}.opencode2dsh.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./opencode2dsh-pr14.patch
      ./opencode2dsh-pr23.patch
    ];
    pnpmDeps = old.pnpmDeps.override {
      patches = [ ./opencode2dsh-pr23.patch ];
      hash = "sha256-oTImIPNGDoTxZnUdgGqRe0hU/cJz2rjnMbaM3Jv/iuw=";
    };
  });

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
    nur-DataEraserC.packages.${pkgs.system}.dsh-turn-rewind
    # Retired: cliproxyapi is no longer deployed.
    # pkgs.dsh.bundles.cpa
    # Incompatible with the current kernel; keep disabled until it is fixed.
    # pkgs.dsh.bundles.message-edit
    pkgs.dsh.bundles.agent-teams
    # pkgs.dsh.bundles.ads
    pkgs.dsh.bundles.navbar
    opencode2dsh
    nur-DataEraserC.packages.${pkgs.system}.dsh-bas-remote
    # nur-DataEraserC.packages.${pkgs.system}.dsh-git-worktree
    nur-DataEraserC.packages.${pkgs.system}.dsh-worktree
    nur-DataEraserC.packages.${pkgs.system}.modlens
    # nur-DataEraserC.packages.${pkgs.system}.dsh-oauthpro
    # only work on 0.1.7-alpha.1 || 0.1.7-alpha.2 || 0.1.7-rc.1 || 0.1.7-rc.2
    # nur-DataEraserC.packages.${pkgs.system}.dsh-notifier
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
in
{
  imports = [ deepseek-harness.nixosModules.default ];

  options.modules.dsh = {
    enable = lib.mkEnableOption "DeepSeek Harness (dsh)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # pkgs.dsh.dsh-desktop

      nur-DataEraserC.packages.${pkgs.system}.qq-bridge
      nur-DataEraserC.packages.${pkgs.system}.dsh-plugin-guard
    ];

    programs.dsh = {
      enable = true;
      profiles = {
        # Full profiles: entry + shared base + shared extras.
        tui.bundles = tuiBundles;
        web.bundles = webBundles;

        # Minimal fallback for the plain surfaces: entry + shared base only.
        #   dsh --profile nix-tui-failsafe
        #   dsh --profile nix-web-failsafe
        tui-failsafe.bundles = tuiFailsafeBundles;
        web-failsafe.bundles = webFailsafeBundles;

        # Group-chat combos: full = the whole web stack + the QQ stack, so
        # one instance serves both the web and the qq use; the failsafe drops
        # only the shared extras (the former `web-qq` composition).
        #   dsh --profile nix-web-qq
        #   dsh --profile nix-web-qq-failsafe
        web-qq.bundles = webQQBundles;
        web-qq-failsafe.bundles = webQQFailsafeBundles;

        # The same composition as `web`, with the webserver row patched to
        # bind every interface (see `webLanPatch` above):
        #   dsh --profile nix-web-lan --no-open
        web-lan = {
          bundles = webBundles;
          patch = webLanPatch;
        };
        web-lan-failsafe = {
          bundles = webFailsafeBundles;
          patch = webLanPatch;
        };

        # The two qq combos with the same LAN webserver patch — deliberate
        # starts, like `web-lan`:
        #   dsh --profile nix-web-qq-lan --no-open
        #   dsh --profile nix-web-qq-lan-failsafe --no-open
        web-qq-lan = {
          bundles = webQQBundles;
          patch = webLanPatch;
        };
        web-qq-lan-failsafe = {
          bundles = webQQFailsafeBundles;
          patch = webLanPatch;
        };
      };
      defaultProfile = config.programs.dsh.profiles.tui.materializedName;
    };

    system.userActivationScripts.dsh-qq-presets = {
      text = ''
        mkdir -p ~/.dsh/.agent-presets/qq-chat
        cp -r ${
          nur-DataEraserC.packages.${pkgs.system}.qq-bridge-dsh
        }/share/qq-bridge-presets/qq-chat/. ~/.dsh/.agent-presets/qq-chat/
        mkdir -p ~/.dsh/.agent-presets/qq-chat-v2
        cp -r ${
          nur-DataEraserC.packages.${pkgs.system}.qq-bridge-dsh
        }/share/qq-bridge-presets/qq-chat-v2/. ~/.dsh/.agent-presets/qq-chat-v2/
      '';
    };
  };
}
