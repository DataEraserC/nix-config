{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.port-forwarding;

  tunnelOpts = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the tunnel (used for systemd service name)";
      };
      localPort = lib.mkOption {
        type = lib.types.port;
        description = "Local port to listen on";
      };
      remoteHost = lib.mkOption {
        type = lib.types.str;
        description = "Remote host IP address";
      };
      remotePort = lib.mkOption {
        type = lib.types.port;
        description = "Remote port to forward to";
      };
    };
  };

  mkSocatService =
    tunnel:
    let
      serviceName = "port-forward-${tunnel.name}";
    in
    {
      ${serviceName} = {
        description = "Port forwarding: ${tunnel.name} (localhost:${toString tunnel.localPort} -> ${tunnel.remoteHost}:${toString tunnel.remotePort})";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString tunnel.localPort},fork,reuseaddr,bind=127.0.0.1 TCP:${tunnel.remoteHost}:${toString tunnel.remotePort}";
          Restart = "always";
          RestartSec = 5;
        };
        wantedBy = [ "multi-user.target" ];
      };
    };

  mkNftablesRule =
    tunnel:
    "tcp dport ${toString tunnel.localPort} dnat to ${tunnel.remoteHost}:${toString tunnel.remotePort}";

  nftablesRuleset = lib.concatStringsSep "\n" (map mkNftablesRule cfg.tunnels);
in
{
  options.modules.port-forwarding = {
    enable = lib.mkEnableOption "port forwarding services";

    implementation = lib.mkOption {
      type = lib.types.enum [
        "socat"
        "nftables"
      ];
      default = "socat";
      description = ''
        Implementation method:
        - socat: userspace TCP forwarding (safe, no firewall side effects)
        - nftables: kernel-level DNAT forwarding (more efficient, but may affect firewall)
      '';
    };

    tunnels = lib.mkOption {
      type = lib.types.listOf tunnelOpts;
      default = [ ];
      description = "List of port forwarding tunnels to create";
    };
  };

  config = lib.mkIf cfg.enable {
    # socat implementation (default)
    systemd.services = lib.mkIf (cfg.implementation == "socat") (
      lib.mkMerge (map mkSocatService cfg.tunnels)
    );

    # nftables implementation (optional)
    networking.nftables = lib.mkIf (cfg.implementation == "nftables") {
      enable = true;
      ruleset = ''
        table ip nat {
          chain prerouting {
            type nat hook prerouting priority dstnat;
            ${nftablesRuleset}
          }
        }
      '';
    };
  };
}
