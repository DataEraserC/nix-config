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
  };
}
