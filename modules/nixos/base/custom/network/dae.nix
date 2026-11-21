# dae - eBPF/tproxy transparent proxy, packaged as one self-contained module.
#
# The host supplies its own dae config files via `installFiles` (each entry is at
# least <source, target>, optionally with mode/owner/group); this module owns the
# rest: the daeuniverse NixOS modules, the dae service and the activation script
# that installs the files under /etc/dae. Currently only enabled on idols-ai.
{
  config,
  lib,
  pkgs,
  daeuniverse,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.dae;

  # Parse a single-unit duration ("30min" / "2h" / "1day") into whole minutes.
  # Only forced when autoReload is enabled (the timer attrs are lazy mkIfs).
  autoReloadMinutes =
    let
      m = builtins.match "([0-9]+)(min|h|hr|day)" cfg.autoReload.interval;
    in
    if m == null then
      throw ''modules.dae.autoReload.interval: "${cfg.autoReload.interval}" is not a supported duration; use one unit, e.g. "30min", "2h" or "1day"''
    else
      let
        count = builtins.fromJSON (builtins.elemAt m 0);
        unit = builtins.elemAt m 1;
      in
      count
      * (
        if unit == "min" then
          1
        else if unit == "h" || unit == "hr" then
          60
        else
          1440
      );
in
{
  imports = [
    daeuniverse.nixosModules.dae
    daeuniverse.nixosModules.daed
  ];

  options.modules.dae = {
    enable = lib.mkEnableOption "the dae transparent proxy, along with installFiles and the activation script";

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/dae/config.dae";
      description = "Main dae config path passed to services.dae.configFile; normally also one of installFiles' targets.";
    };

    assetsPath = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      default = "${nur-DataEraserC.packages.${pkgs.system}.v2ray-rules-dat}/share/v2ray-rules-dat";
      description = "Directory holding geoip.dat / geosite.dat (DAE_LOCATION_ASSET); defaults to nur-DataEraserC's v2ray-rules-dat share directory.";
    };

    installFiles = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            source = lib.mkOption {
              type = lib.types.either lib.types.path lib.types.str;
              description = "Source file: a repo path (copied into the store) or an absolute runtime path such as an agenix secret.";
            };
            target = lib.mkOption {
              type = lib.types.str;
              description = "Absolute destination path, e.g. /etc/dae/config.dae.";
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "0600";
              description = "File mode passed to install -m; dae refuses group-writable or world-readable configs.";
            };
            owner = lib.mkOption {
              type = lib.types.str;
              default = "root";
              description = "File owner passed to install -o.";
            };
            group = lib.mkOption {
              type = lib.types.str;
              default = "root";
              description = "File group passed to install -g.";
            };
          };
        }
      );
      default = [ ];
      description = "Files installed into the dae config tree at activation: entries are <source, target> pairs extended with mode/owner/group as needed.";
    };

    autoReload = {
      enable = lib.mkEnableOption ''
        a periodic `systemctl reload dae`; dae only fetches subscriptions at
        startup and on reload, so a timer keeps the node pool following
        refreshed subscriptions without a manual reload or rebuild
      '';

      interval = lib.mkOption {
        type = lib.types.str;
        default = "60min";
        example = "2h";
        description = ''
          Time between reloads as a duration with a single unit: minutes
          (`30min`), hours (`2h`) or days (`1day`); seconds are not supported.
          The value feeds the timer's OnBootSec/OnUnitActiveSec directly.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.dae = {
      enable = true;
      configFile = cfg.configFile;
      # tproxy only serves locally injected transparent traffic, so keep 12345
      # closed on the firewall; tproxy_port_protect already blocks direct hits.
      openFirewall.enable = false;
      assetsPath = cfg.assetsPath;
    };

    # daed shares dae's tproxy port - only one of them may run, pin daed off here.
    services.daed.enable = false;

    # Install the host-provided config files at activation; mode defaults to
    # 0600 root:root so dae's permission check keeps passing.
    system.activationScripts.installDaeConfig = lib.concatMapStringsSep "\n" (file: ''
      install -D -m ${file.mode} -o ${file.owner} -g ${file.group} ${file.source} ${file.target}
    '') cfg.installFiles;

    # Periodic reload (autoReload): each run skips while dae is stopped, and
    # dae's own reload guard keeps a run that resolves 0 nodes harmless.
    systemd.services.dae-auto-reload = lib.mkIf cfg.autoReload.enable {
      description = "Periodically reload dae to re-fetch subscriptions";
      serviceConfig.Type = "oneshot";
      script = ''
        if ! ${pkgs.systemd}/bin/systemctl is-active --quiet dae; then
          echo "dae is not active, skipping reload" >&2
          exit 0
        fi
        exec ${pkgs.systemd}/bin/systemctl reload dae
      '';
    };

    systemd.timers.dae-auto-reload = lib.mkIf cfg.autoReload.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "${toString autoReloadMinutes}min";
        OnUnitActiveSec = "${toString autoReloadMinutes}min";
      };
    };
  };
}
