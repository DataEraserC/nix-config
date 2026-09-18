{
  pkgs,
  deepseek-harness,
  nur-DataEraserC,
  config,
  lib,
  ...
}:
let
  cfg = config.modules.desktop.dsh;

  # Composition shared by the Web profiles. A profile owns its own bundle list,
  # so the exposed variant restates it instead of inheriting it; the plugin
  # packages themselves are hoisted once under `$DSH_HOME/profiles/node_modules`.
  webBundles = [
    pkgs.dsh.bundles.web-app
    pkgs.dsh.bundles.modsearch
    pkgs.dsh.bundles.turn-rewind
    pkgs.dsh.bundles.web-ui
    pkgs.dsh.bundles.cpa
    pkgs.dsh.bundles.remote
    # pkgs.dsh.bundles.message-edit
    pkgs.dsh.bundles.agent-teams
    # pkgs.dsh.bundles.ads
    pkgs.dsh.bundles.navbar
    nur-DataEraserC.packages.${pkgs.system}.opencode2dsh
    nur-DataEraserC.packages.${pkgs.system}.dsh-bas-remote
  ];
in
{
  imports = [ deepseek-harness.nixosModules.default ];

  options.modules.desktop.dsh = {
    enable = lib.mkEnableOption "DeepSeek Harness (dsh)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # pkgs.dsh.dsh-desktop
    ];

    programs.dsh = {
      enable = true;
      profiles = {
        tui.bundles = [
          pkgs.dsh.bundles.tui
          pkgs.dsh.bundles.modsearch
          pkgs.dsh.bundles.turn-rewind
          pkgs.dsh.bundles.cpa
          pkgs.dsh.bundles.remote
          # pkgs.dsh.bundles.message-edit
          pkgs.dsh.bundles.agent-teams
          # pkgs.dsh.bundles.ads
          pkgs.dsh.bundles.navbar
          nur-DataEraserC.packages.${pkgs.system}.opencode2dsh
          nur-DataEraserC.packages.${pkgs.system}.dsh-bas-remote
        ];
        web.bundles = webBundles;

        # The same composition as `web`, with the webserver row patched to bind
        # every interface. dsh refuses `--host 0.0.0.0` at startup, so the bind
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
        web-lan = {
          bundles = webBundles;
          patch = ''
            - id: webserver
              config:
                host: 0.0.0.0
                port: !!js ctx.webStartup.port ?? 3080
                compression: gzip
                compressionLevel: 1
                compressionThresholdBytes: 1024
          '';
        };
      };
      defaultProfile = config.programs.dsh.profiles.tui.materializedName;
    };
  };
}
