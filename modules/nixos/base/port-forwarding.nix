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
      listenAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "0.0.0.0";
        description = ''
          socat implementation only: local address to listen on. Unset keeps the
          safe `127.0.0.1` default. `0.0.0.0` listens on every interface, and an
          address owned by a tunnel interface restricts the listener to that
          overlay. An IPv6 literal selects the IPv6 listener automatically.
        '';
      };
      matchAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "10.126.126.150";
        description = ''
          nftables implementation only: destination address the DNAT rule
          matches. Unset matches every destination address. Use `listenAddress`
          for the socat implementation.
        '';
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

  isIPv6 = address: lib.hasInfix ":" address;

  # The nftables ruleset is an IPv4 table, so a numeric in-range literal is the
  # only address shape that implementation can express.
  isIPv4Literal =
    address:
    let
      octets = lib.splitString "." address;
    in
    lib.length octets == 4
    && lib.all (octet: builtins.match "[0-9]+" octet != null && lib.toInt octet <= 255) octets;

  looksNumeric = address: builtins.match "[0-9.]+" address != null;

  # Inputs the IPv4 nftables ruleset certainly cannot express: an IPv6 literal, or
  # a numeric literal that is malformed. Either one makes nft reject the whole
  # ruleset, so these fail the build rather than the boot.
  unsupportedByNftables = address: isIPv6 address || (looksNumeric address && !isIPv4Literal address);

  # A hostname may load, but only because nft resolves it once at load time.
  isHostname = address: !looksNumeric address && !isIPv6 address;

  # A listening socket takes the bare address, and socat resolves one address in
  # a single protocol family: `TCP-LISTEN` rejects an IPv6 literal outright.
  socatListenSpec =
    tunnel:
    let
      address = if tunnel.listenAddress == null then "127.0.0.1" else tunnel.listenAddress;
    in
    "${
      if isIPv6 address then "TCP6-LISTEN" else "TCP-LISTEN"
    }:${toString tunnel.localPort},fork,reuseaddr,bind=${address}";

  # A remote IPv6 host needs brackets because the address itself contains the
  # `host:port` separator.
  socatRemoteSpec =
    tunnel:
    if isIPv6 tunnel.remoteHost then
      "TCP6:[${tunnel.remoteHost}]:${toString tunnel.remotePort}"
    else
      "TCP:${tunnel.remoteHost}:${toString tunnel.remotePort}";

  listenAddressOf =
    tunnel: if tunnel.listenAddress == null then "127.0.0.1" else tunnel.listenAddress;

  mkSocatService =
    tunnel:
    let
      serviceName = "port-forward-${tunnel.name}";
    in
    {
      ${serviceName} = {
        description = "Port forwarding: ${tunnel.name} (${listenAddressOf tunnel}:${toString tunnel.localPort} -> ${tunnel.remoteHost}:${toString tunnel.remotePort})";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.socat}/bin/socat ${socatListenSpec tunnel} ${socatRemoteSpec tunnel}";
          Restart = "always";
          RestartSec = 5;
        };
        wantedBy = [ "multi-user.target" ];
      };
    };

  # The nftables table is IPv4 (`table ip nat`), so this implementation carries
  # no IPv6 form.
  mkNftablesRule =
    tunnel:
    "${
      lib.optionalString (tunnel.matchAddress != null) "ip daddr ${tunnel.matchAddress} "
    }tcp dport ${toString tunnel.localPort} dnat to ${tunnel.remoteHost}:${toString tunnel.remotePort}";

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
        - nftables: kernel-level DNAT forwarding (more efficient, but may affect
          firewall; IPv4 only)
      '';
    };

    tunnels = lib.mkOption {
      type = lib.types.listOf tunnelOpts;
      default = [ ];
      description = "List of port forwarding tunnels to create";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.implementation == "socat" || lib.all (tunnel: tunnel.listenAddress == null) cfg.tunnels;
        message = "modules.port-forwarding: `tunnels.*.listenAddress` configures the socat listener, but `implementation` is \"nftables\". Set `matchAddress` instead, or switch `implementation` to \"socat\".";
      }
      {
        assertion =
          cfg.implementation == "nftables" || lib.all (tunnel: tunnel.matchAddress == null) cfg.tunnels;
        message = "modules.port-forwarding: `tunnels.*.matchAddress` configures the nftables DNAT match, but `implementation` is \"socat\". Set `listenAddress` instead, or switch `implementation` to \"nftables\".";
      }
      {
        assertion =
          cfg.implementation == "socat"
          || lib.all (
            tunnel: tunnel.matchAddress == null || !unsupportedByNftables tunnel.matchAddress
          ) cfg.tunnels;
        message = "modules.port-forwarding: the nftables ruleset is an IPv4 table (`table ip nat`), so `tunnels.*.matchAddress` cannot be an IPv6 address or a malformed IPv4 literal; nft rejects the whole ruleset. Use the socat implementation to match IPv6.";
      }
      {
        assertion =
          cfg.implementation == "socat"
          || lib.all (tunnel: !unsupportedByNftables tunnel.remoteHost) cfg.tunnels;
        message = "modules.port-forwarding: the nftables ruleset is an IPv4 table (`table ip nat`), so `tunnels.*.remoteHost` cannot be an IPv6 address or a malformed IPv4 literal; nft rejects the whole ruleset. Use the socat implementation to forward to IPv6.";
      }
    ];

    # A hostname is resolved once when the kernel ruleset loads, so a DNS change
    # or a boot without DNS silently freezes or breaks the tunnel.
    warnings =
      lib.optional
        (
          cfg.implementation == "nftables"
          && lib.any (
            tunnel:
            (tunnel.matchAddress != null && isHostname tunnel.matchAddress) || isHostname tunnel.remoteHost
          ) cfg.tunnels
        )
        "modules.port-forwarding: an nftables address hostname is resolved once at ruleset load time, so a DNS change or a boot without DNS silently freezes or breaks the tunnel; prefer a numeric address.";

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
