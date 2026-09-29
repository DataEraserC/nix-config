{
  pkgs,
  deepseek-harness,
  nur-DataEraserC,
  config,
  myvars,
  lib,
  mylib,
  ...
}:
let
  cfg = config.modules.dsh;

  # Temporary fixes for FishBottle7/opencode2dsh, carried as a pinned commit
  # of the DataEraserC fork instead of local patch files: the upstream repo
  # does not merge the PRs we need, and three stacked patch files were a
  # maintenance burden (context drift on every upstream tag). The fork branch
  # `master-patches` (rev pinned below) is upstream master (0.3.3 era) plus,
  # in order:
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
  # Both original commits keep their upstream author/message; the new commit
  # is ours. Rebase the fork branch onto the next upstream tag when
  # nur-DataEraserC catches up, then drop this override entirely. `patches = [ ]`
  # clears whatever upstream adds later, so only the pinned tree ships.
  opencode2dsh = nur-DataEraserC.packages.${pkgs.system}.opencode2dsh.overrideAttrs (
    old:
    let
      forkSrc = pkgs.fetchFromGitHub {
        owner = "DataEraserC";
        repo = "opencode2dsh";
        rev = "b41b2238cd764c74998e03f6f99d7a60878b3435";
        hash = "sha256-1ZQh8+k6x2p0sRKKl2HGSm370/IDAa1kaugyxH/UKpo=";
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
    pkgs.dsh.bundles.agent-teams
    # pkgs.dsh.bundles.ads
    # Archived: dsh ships a built-in navbar implementation now.
    # pkgs.dsh.bundles.navbar
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
    # Agent presets (qq-chat / qq-chat-v2) own the execution-time guard
    # since they became their own bundle: QQ presets' qq-tool-restrict.mjs
    # rejects anything outside its whitelist — admit modlens' vision tool
    # here (exact name → SAFE_EXACT; dev_* stays denied no matter what).
    # The override moved here with the guard implementation.
    (nur-DataEraserC.packages.${pkgs.system}.qq-agent-presets.override {
      extraAllowedTools = [ "modlens_read_image" ];
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
      # modlens is declared as a dsh bundle above and ships inside dsh's own
      # closure, but neither path links its bin into PATH, so `modlens` was
      # not runnable from a shell (the dsh tool calls it by absolute store
      # path, which is why modlens_read_image worked anyway). Adding it here
      # exposes the CLI for manual `doctor` / `config set` / `analyze` use.
      nur-DataEraserC.packages.${pkgs.system}.modlens
    ];

    programs.dsh = {
      enable = true;

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
