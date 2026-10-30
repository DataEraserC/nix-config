# ===============================================================================
#
# gost - authenticated SOCKS5 + HTTP proxy, optionally chained through an
#        upstream proxy (https://github.com/go-gost/gost, nixpkgs `gost`).
#
# Purpose here:
#   - expose authenticated proxy entry points (SOCKS5 on 1080, HTTP on 1081, on
#     every host that enables it) so a client reaches the host's
#     intranet/overlay resources through
#       --proxy socks5h://<user>:<pass>@<host>:1080   (curl, ssh, proxychains)
#       --proxy http://<user>:<pass>@<host>:1081      (browsers, npm, git, ...)
#   - chain one listener through another host's proxy, e. wsl-work:31080/31081
#     forward through idols-ai:1080, so a client using them reaches idols-ai's
#     LOOPBACK services (the final hop resolves 127.0.0.1 on idols-ai itself) -
#     i. the dsh GUI on idols-ai 127.0.0.1:9900:
#
#       client -> wsl-work:31081 (auth) -> idols-ai:1080 (auth) -> 127.0.0.1:9900
#
# Why an HTTP listener as well: browsers do not speak authenticated SOCKS5 -
# Chrome/Chromium/Edge/Safari cannot send a SOCKS username/password at all
# (Firefox only via about:config) - while all of them speak an HTTP proxy and
# answer a 407 with a Basic `Proxy-Authorization` prompt. `protocol` selects the
# wire protocol per instance; the chain connector stays SOCKS5 regardless,
# because gost converts between the listener protocol and the hop.
#
# `protocol = "auto"` is available (gost routes SOCKS4/SOCKS5/HTTP by the first
# bytes) but NOT recommended on an entry point: the auto handler also treats a
# bare TLS ClientHello as a transparent SNI proxy, on a path that runs BEFORE
# authentication (go-gost/x handler/auto/handler.go, handleTLS), so the port
# would double as an unauthenticated TLS proxy. Prefer an explicit
# `socks5`/`http` listener.
#
# Browser setup - the reason the HTTP listeners exist:
#   - Chromium/Chrome: `--proxy-server=http://<host>:1081`; the credential
#     prompt appears once per session (Chromium strips user:pass from a proxy
#     URL, so the credentials cannot be embedded there).
#   - Firefox: HTTP proxy host/port, or `http://<user>:<pass>@<host>:1081`.
#   - Both bypass localhost/127.0.0.1 implicitly - clear that bypass when the
#     TARGET is a remote loopback service (the dsh GUI): Chromium
#     `--proxy-bypass-list="<-loopback>"`, Firefox emptied "No proxy for".
#
# Authentication is MANDATORY and shared: every listener enforces auth via a
# gost `auther` reading the agenix secret "gost-proxy.auth" (a single
# space-separated `<username> <password>` line; identical on every host so one
# client config works everywhere), and a chained hop sends the same credentials
# to its upstream with `connector.auth`. Both are file loaders with a reload
# interval, so an agenix re-encryption is picked up without a restart, and a
# missing file fails CLOSED (every request is rejected until agenix writes it).
#
# One systemd unit (gost-proxy) runs every ACTIVE instance of the host from one
# JSON config built with builtins.toJSON - the schema is fixed, nothing is
# generated at runtime. An instance with `enable = false` (and a host whose
# instances are all disabled) is left out of that config, so the unit is not
# started at all: that is how a listener is retired without deleting its
# declaration - or the port another host's `chainUpstream` points at.
#
# Instance keys are `<destination-host>-<protocol>` - idols-ai-socks5,
# idols-ai-http, wsl-work-http - naming the host whose network the entry point
# resolves on plus the protocol the client speaks. The same key therefore means
# the same destination on every machine (direct on that host, chained through
# it elsewhere), and it is the gost service/chain name that shows up in the
# journal.
#
# Exposure: instances bind address (default 0.0.0.0) and rely on the host
# firewall's trustedInterfaces (easytier/tailscale/zerotier) for reachability;
# openFirewall additionally allows the port on EVERY interface (e. the campus
# LAN). Keep it off unless needed - proxy credentials travel in clear text on
# an unencrypted LAN hop.
#
# Retrieve the credentials (from the secrets/ directory, interactive):
#   agenix -d -i ~/.ssh/id_ed25519 ./agenix/gost-proxy.auth.age
# Check service status / logs:
#   systemctl status gost-proxy
#   journalctl -u gost-proxy --since "2 minutes ago"
# Smoke-test a local listener (substitute the decrypted credentials):
#   curl --proxy socks5h://<user>:<pass>@127.0.0.1:1080 http://example.com
#   curl --proxy http://<user>:<pass>@127.0.0.1:1081 http://example.com
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

  # Instances that are actually deployed (`enable = false` pins a declaration
  # in place while its listener is retired). Everything below - services,
  # chains, firewall ports, uniqueness assertions - is derived from these, so a
  # disabled instance cannot conflict with an active one on the same port and
  # disappears from the gost config entirely.
  activeInstances = lib.filterAttrs (_: inst: inst.enable) cfg.instances;

  instanceModule =
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether this listener is deployed. `false` keeps the declaration -
            and the port the registry documents and a chained host's
            `chainUpstream` points at - but emits no service, no chain and no
            firewall port, and drops it from the gost config. Use it to retire
            a listener without deleting the entry; with every instance disabled
            the host runs no gost process at all.
          '';
        };

        port = lib.mkOption {
          type = lib.types.port;
          description = "TCP port the listener of this instance (SOCKS5 or HTTP) binds.";
        };

        protocol = lib.mkOption {
          type = lib.types.enum [
            "socks5"
            "http"
            "auto"
          ];
          default = "socks5";
          description = ''
            Wire protocol of the listener.
            - "socks5": authenticated SOCKS5. For SOCKS-aware clients only -
              browsers cannot send credentials over SOCKS5 (Chromium not at
              all, Firefox through about:config).
            - "http": HTTP proxy - CONNECT for https, absolute-form requests for
              http - authenticated with Basic `Proxy-Authorization`, which every
              browser supports. This is the browser-facing twin of "socks5".
            - "auto": gost guesses SOCKS4/SOCKS5/HTTP from the first bytes. Not
              recommended here: the auto handler also serves a bare TLS
              ClientHello as a transparent SNI proxy and that path is NOT
              authenticated (go-gost/x handler/auto/handler.go, handleTLS).
          '';
        };

        address = lib.mkOption {
          type = lib.types.str;
          default = "0.0.0.0";
          description = ''
            Bind address of the listener. The default listens on all
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
            Optional upstream proxy (`host:port`) this instance chains
            through: the listener itself requires auth, then forwards every
            client connection to the upstream with the same credentials, and
            the upstream resolves the destination on ITS side - that is how a
            chained instance reaches the upstream host's loopback services
            (e. wsl-work:31080 -> idols-ai:1080 -> 127.0.0.1:9900 for dsh).
            The hop speaks whatever `chainProtocol` says, independent of this
            listener's `protocol` (gost converts between the two), so an HTTP
            listener can chain through the upstream's SOCKS5 port.
            null (default) makes it a plain local proxy.
          '';
        };

        chainProtocol = lib.mkOption {
          type = lib.types.enum [
            "socks5"
            "http"
          ];
          default = "socks5";
          description = ''
            Protocol the chained hop uses to reach `chainUpstream` - it has to
            match the upstream instance's `protocol`. Defaults to "socks5",
            the protocol of the `proxy` listeners here; set "http" when the
            upstream listener you chain through is an HTTP one.
          '';
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Open `port` in the host firewall for every interface, not just the
            trusted overlay interfaces. Only enable when a client that is
            outside every overlay must connect directly - proxy username/
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
      type = inst.protocol;
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
              type = inst.chainProtocol;
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

  chainedInstances = lib.filterAttrs (_: inst: inst.chainUpstream != null) activeInstances;

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
    services = lib.mapAttrsToList mkService activeInstances;
  }
  // lib.optionalAttrs (lib.length (lib.attrNames chainedInstances) > 0) {
    chains = lib.mapAttrsToList mkChain chainedInstances;
  };

  configFile = pkgs.writeText "gost-proxy.json" (builtins.toJSON gostConfig);

  listenAddrs = lib.mapAttrsToList (_: inst: "${inst.address}:${toString inst.port}") activeInstances;
  listenPorts = lib.mapAttrsToList (_: inst: inst.port) activeInstances;
in
{
  options.modules.gost-proxy = {
    enable = lib.mkEnableOption ''
      gost SOCKS5/HTTP proxy with mandatory authentication (agenix secret
      "gost-proxy.auth"), optionally chained through another host's proxy
    '';

    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule instanceModule);
      default = { };
      example = {
        # the local host's own entry points ...
        wsl-work-socks5 = {
          port = 1080;
        };
        wsl-work-http = {
          port = 1081;
          protocol = "http";
        };
        # ... plus one chained through another host's listener
        idols-ai-socks5 = {
          port = 31080;
          chainUpstream = "10.126.126.150:1080";
        };
      };
      description = ''
        The gost listeners of this host, keyed by instance name (used for the
        service and chain names). Each entry is one authenticated listener of
        its own `protocol` (SOCKS5 or HTTP) on its own port; `chainUpstream`
        turns it into a forwarder to another host's proxy, and `enable = false`
        retires a listener while keeping its declaration. Without any instance
        the enable flag is a configuration bug and fails the eval.

        Name an instance `<destination-host>-<protocol>` - `idols-ai-socks5`,
        `idols-ai-http`, `wsl-work-http` - where the host is the one whose
        network the entry point resolves on. The same name then means the same
        destination and protocol on every host (directly on that host, chained
        through it elsewhere), and gost's own service/chain names in the
        journal stay self-describing.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # An enabled module with no declared instance is a config bug (nothing
    # would ever be served); two ACTIVE instances on the same address:port
    # would make gost fail at runtime - also a config bug. Disabled instances
    # bind nothing, so they are exempt from the uniqueness checks.
    assertions = [
      {
        assertion = lib.length (lib.attrNames cfg.instances) > 0;
        message = "modules.gost-proxy.enable requires at least one entry in modules.gost-proxy.instances (e. instances.idols-ai-socks5.port = 1080)";
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
    ) (lib.attrValues activeInstances);

    # No active instance = nothing to serve: skip the unit entirely instead of
    # starting a gost process with an empty service list.
    systemd.services.gost-proxy = lib.mkIf (activeInstances != { }) {
      description = "gost authenticated proxy (SOCKS5/HTTP, optionally chained)";
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
