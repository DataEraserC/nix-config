# ===============================================================================
#
# gost - authenticated SOCKS5 proxy, optionally chained through an upstream
#        proxy (https://github.com/go-gost/gost, nixpkgs `gost`).
#
# Purpose here:
#   - expose an authenticated SOCKS5 entry point (port 1080 on every host that
#     enables it) so a client can reach the host's intranet/overlay resources
#     through `--proxy socks5h://<user>:<pass>@<host>:1080`;
#   - chain one listener through another host's proxy, e. wsl-work:31080
#     forwards through idols-ai:1080, so a client using wsl-work:31080 reaches
#     idols-ai's LOOPBACK services (the final hop resolves 127.0.0.1 on
#     idols-ai itself) - i. the dsh GUI on idols-ai 127.0.0.1:9900:
#
#       client -> wsl-work:31080 (auth) -> idols-ai:1080 (auth) -> 127.0.0.1:9900
#
# Authentication is MANDATORY and shared: every listener enforces SOCKS5 auth
# via a gost `auther` reading the agenix secret "gost-proxy.auth" (a single
# space-separated `<username> <password>` line; identical on every host so one
# client config works everywhere), and a chained hop sends the same credentials
# to its upstream with `connector.auth`. Both are file loaders with a reload
# interval, so an agenix re-encryption is picked up without a restart, and a
# missing file fails CLOSED (every request is rejected until agenix writes it).
#
# One systemd unit (gost-proxy) runs all instances of the host from one JSON
# config built with builtins.toJSON - the schema is fixed, nothing is
# generated at runtime.
#
# Exposure: instances bind address (default 0.0.0.0) and rely on the host
# firewall's trustedInterfaces (easytier/tailscale/zerotier) for reachability;
# openFirewall additionally allows the port on EVERY interface (e. the campus
# LAN). Keep it off unless needed - SOCKS5 credentials travel in clear text on
# an unencrypted LAN hop.
#
# Retrieve the credentials (from the secrets/ directory, interactive):
#   agenix -d -i ~/.ssh/id_ed25519 ./agenix/gost-proxy.auth.age
# Check service status / logs:
#   systemctl status gost-proxy
#   journalctl -u gost-proxy --since "2 minutes ago"
# Smoke-test a local listener (substitute the decrypted credentials):
#   curl --proxy socks5h://<user>:<pass>@127.0.0.1:1080 http://example.com
# ===============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.gost-proxy;

  # Both the listener auther and the chained hop's connector read this one
  # agenix secret. `or (throw ...)` yields a readable eval error when the host
  # enables gost-proxy without declaring the secret (secrets/nixos_agenix.nix).
  authPath =
    config.age.secrets."gost-proxy.auth".path or (throw ''
      modules.gost-proxy.enable requires the agenix secret "gost-proxy.auth" -
      import secrets/nixos_agenix.nix with modules.secrets.desktop.enable = true.
    '');

  autherName = "gost-auth";
  chainName = name: "chain-${name}";

  instanceModule =
    { name, ... }:
    {
      options = {
        port = lib.mkOption {
          type = lib.types.port;
          description = "TCP port the SOCKS5 listener of this instance binds.";
        };

        address = lib.mkOption {
          type = lib.types.str;
          default = "0.0.0.0";
          description = ''
            Bind address of the SOCKS5 listener. The default listens on all
            interfaces, but the host firewall only exposes it on
            trustedInterfaces (easytier/tailscale/zerotier) unless
            openFirewall is set - bind `127.0.0.1` to keep it strictly local.
          '';
        };

        chainUpstream = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "10.126.126.150:1080";
          description = ''
            Optional upstream SOCKS5 proxy (`host:port`) this instance chains
            through: the listener itself requires auth, then forwards every
            client connection to the upstream with the same credentials, and
            the upstream resolves the destination on ITS side - that is how a
            chained instance reaches the upstream host's loopback services
            (e. wsl-work:31080 -> idols-ai:1080 -> 127.0.0.1:9900 for dsh).
            null (default) makes it a plain local proxy.
          '';
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Open `port` in the host firewall for every interface, not just the
            trusted overlay interfaces. Only enable when a client that is
            outside every overlay must connect directly - SOCKS5 username/
            password auth travels in clear text on a plain LAN hop.
          '';
        };
      };
    };

  # One gost service (listener) per instance: mandatory auther, plus a chain
  # reference when the instance forwards to an upstream.
  mkService = name: inst: {
    inherit name;
    addr = "${inst.address}:${toString inst.port}";
    handler = {
      type = "socks5";
      auther = autherName;
    }
    // lib.optionalAttrs (inst.chainUpstream != null) {
      chain = chainName name;
    };
    listener = {
      type = "tcp";
    };
  };

  # One chain per chained instance: a single hop whose connector authenticates
  # against the upstream with the same agenix credentials (credentials live in
  # `connector.auth`, a plain { username, password } sibling is NOT accepted).
  mkChain = name: inst: {
    name = chainName name;
    hops = [
      {
        name = "hop";
        nodes = [
          {
            name = "upstream";
            addr = inst.chainUpstream;
            connector = {
              type = "socks5";
              auth = {
                file = authPath;
              };
            };
            dialer = {
              type = "tcp";
            };
          }
        ];
      }
    ];
  };

  chainedInstances = lib.filterAttrs (_: inst: inst.chainUpstream != null) cfg.instances;

  # Static config for `gost -C`: authers (listener side) + services + chains
  # (upstream side), both pointing at the same decrypted secret file.
  gostConfig = {
    authers = [
      {
        name = autherName;
        file = {
          path = authPath;
          reload = "5s";
        };
      }
    ];
    services = lib.mapAttrsToList mkService cfg.instances;
  }
  // lib.optionalAttrs (lib.length (lib.attrNames chainedInstances) > 0) {
    chains = lib.mapAttrsToList mkChain chainedInstances;
  };

  configFile = pkgs.writeText "gost-proxy.json" (builtins.toJSON gostConfig);

  listenAddrs = lib.mapAttrsToList (_: inst: "${inst.address}:${toString inst.port}") cfg.instances;
  listenPorts = lib.mapAttrsToList (_: inst: inst.port) cfg.instances;
in
{
  options.modules.gost-proxy = {
    enable = lib.mkEnableOption ''
      gost SOCKS5 proxy with mandatory authentication (agenix secret
      "gost-proxy.auth"), optionally chained through another host's proxy
    '';

    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule instanceModule);
      default = { };
      example = {
        proxy = {
          port = 1080;
        };
        idols-ai = {
          port = 31080;
          chainUpstream = "10.126.126.150:1080";
        };
      };
      description = ''
        The gost listeners of this host, keyed by instance name (used for the
        service and chain names). Each entry is one authenticated SOCKS5
        listener on its own port; `chainUpstream` turns it into a forwarder to
        another host's proxy. Without any instance the enable flag is a
        configuration bug and fails the eval.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # An enabled proxy with no listener would deploy a gost process that
    # serves nothing, and two instances on the same address:port would make
    # gost fail at runtime - both are config bugs, so fail the eval on them.
    assertions = [
      {
        assertion = lib.length (lib.attrNames cfg.instances) > 0;
        message = "modules.gost-proxy.enable requires at least one entry in modules.gost-proxy.instances (e. instances.proxy.port = 1080)";
      }
      {
        assertion = lib.length listenAddrs == lib.length (lib.unique listenAddrs);
        message = "modules.gost-proxy.instances: every instance needs a unique address:port, got ${lib.concatStringsSep ", " listenAddrs}";
      }
      {
        assertion = lib.length listenPorts == lib.length (lib.unique listenPorts);
        message = "modules.gost-proxy.instances: every instance needs a unique port, got ${
          lib.concatMapStringsSep ", " toString listenPorts
        }";
      }
    ];

    # openFirewall widens exposure beyond trustedInterfaces; the credentials
    # are the only gate then (and travel unencrypted on a plain LAN hop).
    networking.firewall.allowedTCPPorts = lib.concatMap (
      inst: lib.optional inst.openFirewall inst.port
    ) (lib.attrValues cfg.instances);

    systemd.services.gost-proxy = {
      description = "gost SOCKS5 proxy (authenticated, optionally chained)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.gost} -C ${configFile}";
        Restart = "on-failure";
        RestartSec = "3s";
        # hardening - gost only needs the config in /nix/store, the agenix
        # secret in /run/agenix and outbound sockets; it writes nothing.
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
      };
    };
  };
}
