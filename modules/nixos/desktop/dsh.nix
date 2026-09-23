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
  cfg = config.modules.desktop.dsh;

  # Entry: each surface owns its own launcher bundle, so a profile restates
  # its entry instead of inheriting the other surface's. The plugin packages
  # themselves are hoisted once under `$DSH_HOME/profiles/node_modules`.
  tuiEntry = [ pkgs.dsh.bundles.tui ];
  webEntry = [
    pkgs.dsh.bundles.web-app
    pkgs.dsh.bundles.web-ui
  ];

  # Base shared by every profile of both surfaces: interface-agnostic
  # plugins that are known to work everywhere. A `*-failsafe` profile is
  # exactly `<entry> ++ baseBundles` — the fallback when one of the extras
  # below breaks the composition. modsearch is the essential search
  # replacement and belongs in every profile; without it dsh's search
  # capability is crippled.
  baseBundles = [
    pkgs.dsh.bundles.modsearch
    pkgs.dsh.bundles.remote
  ];

  # Extras shared by the full `tui` and `web` profiles: optional plugins
  # layered on top of the base. Later bundles override earlier Cordis
  # configuration, so keep risky additions here — the failsafe profiles
  # omit this list entirely. The unstable QQ stack lives in `qqBundles`
  # below and ships only in `web-qq`.
  extraBundles = [
    pkgs.dsh.bundles.turn-rewind
    # Retired: cliproxyapi is no longer deployed.
    # pkgs.dsh.bundles.cpa
    # Incompatible with the current kernel; keep disabled until it is fixed.
    # pkgs.dsh.bundles.message-edit
    pkgs.dsh.bundles.agent-teams
    # pkgs.dsh.bundles.ads
    pkgs.dsh.bundles.navbar
    nur-DataEraserC.packages.${pkgs.system}.opencode2dsh
    nur-DataEraserC.packages.${pkgs.system}.dsh-bas-remote
    # nur-DataEraserC.packages.${pkgs.system}.dsh-git-worktree
    nur-DataEraserC.packages.${pkgs.system}.dsh-worktree
  ];

  # QQ group-chat stack: unstable, so it stays out of the full profiles and
  # ships only in `web-qq`. Group chat drives dsh through opencode2dsh, so
  # the bridge pairs with it and needs nothing beyond the shared entry and
  # base.
  qqBundles = [
    nur-DataEraserC.packages.${pkgs.system}.opencode2dsh
    (nur-DataEraserC.packages.${pkgs.system}.qq-bridge-dsh.override {
      qqBridgeHome = "/home/${myvars.username}/.local/share/qq-bridge";
    })
    nur-DataEraserC.packages.${pkgs.system}.qq-mode-console
    # The long-lived group-chat server launch (see ~/tmp/dsh-web) redirects
    # dsh stdout/stderr into `~/.dsh/guard/logs/`; that log home, the
    # incident reports, and the boot-guard rollback all belong to
    # dsh-plugin-guard — the QQ surface depends on it for exactly that part.
    # Unstable otherwise, so it stays parked commented out here; enable it
    # for web-qq once validated.
    # nur-DataEraserC.packages.${pkgs.system}.dsh-plugin-guard
  ];

  tuiBundles = tuiEntry ++ baseBundles ++ extraBundles;
  tuiFailsafeBundles = tuiEntry ++ baseBundles;
  webBundles = webEntry ++ baseBundles ++ extraBundles;
  webFailsafeBundles = webEntry ++ baseBundles;
  webQQBundles = webEntry ++ baseBundles ++ qqBundles;

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

  options.modules.desktop.dsh = {
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

        # Minimal fallback per surface: entry + shared base only.
        #   dsh --profile nix-tui-failsafe
        #   dsh --profile nix-web-failsafe
        tui-failsafe.bundles = tuiFailsafeBundles;
        web-failsafe.bundles = webFailsafeBundles;

        # Group-chat surface: entry + base + QQ stack, no other extras.
        #   dsh --profile nix-web-qq
        web-qq.bundles = webQQBundles;

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
