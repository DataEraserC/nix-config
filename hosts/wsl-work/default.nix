{
  config,
  pkgs,
  lib,
  myvars,
  nur-DataEraserC,
  nixGL,
  ...
}@args:
#############################################################
#
#  Ai - my main computer, with NixOS + AMD Ryzen 9 8945HX + RTX 5070 Laptop GPU, for gaming & daily use.
#
#############################################################
let
  hostName = "work"; # Define your hostname.
  macAddress = "random";
  inherit (myvars.networking) mainGateway mainGateway6 nameservers;
  inherit (myvars.networking.hostsAddr.${hostName}) iface ipv4 ipv6;
  ipv4WithMask = "${ipv4}/24";
  ipv6WithMask = "${ipv6}/64";

in
rec {
  imports = [
    ./netdev-mount.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # ./nvidia.nix
    ./packages.nix
    ./ai

    ./preservation.nix
    ./preservation-downstream.nix
    ./impermanence_addon.nix
    # ./secureboot.nix
    # ./dae.nix

    # wsl related
  ];

  networking = {
    inherit hostName;

    # we use networkd instead
    # networkmanager.enable = false; # provides nmcli/nmtui for wifi adjustment
    # useDHCP = false;

    # desktop need its cli for status bar
    networkmanager.enable = true;
    networkmanager.wifi.macAddress = macAddress;
    networkmanager.ethernet.macAddress = macAddress;
    enableIPv6 = true; # disable ipv6
    extraHosts = myvars.networking.genericHosts;
  };

  # sshd listens on 8022 instead of the stock 22 - taken from the port
  # registry (myvars.networking.services.ssh.hosts.wsl-work). The generated
  # client config (/etc/ssh/ssh_config) reads the same rows, so `ssh work` /
  # `ssh wsl-work` dial 8022 too.
  services.openssh.ports = [ myvars.networking.services.ssh.hosts.wsl-work.port ];

  # ntfy notifications on network up/down events(NM dispatcher, shared script)
  modules.network-event-notify = {
    enable = true;
    inherit hostName;
  };

  # Oray PgyVisitor SDN client
  modules.pgy.enable = true;

  # EasyTier decentralized P2P VPN
  modules.easytier.enable = true;

  # Authenticated SOCKS5 + HTTP proxies (shared
  # modules/nixos/base/custom/network/gost-proxy.nix), named
  # `<destination-host>-<protocol>`:
  # - wsl-work-socks5 / wsl-work-http (1080 / 1081): direct proxy for reaching
  #   intranet/overlay resources via this host (SOCKS5 for curl & co, HTTP for
  #   browsers);
  # - idols-ai-socks5 / idols-ai-http (31080 / 31081): chained through idols-ai's
  #   1080 (easytier 10.126.126.150), so a client of them resolves destinations
  #   ON idols-ai - notably its loopback 127.0.0.1:9900 where the dsh GUI
  #   listens, which is a browser-only service, hence the HTTP twin on 31081.
  #   Same agenix credentials (gost-proxy.auth) on both hosts, so one client
  #   config fits every port.
  # The host firewall is disabled here, so all four ports are reachable
  # wherever this host is (easytier mesh, WSL localhost forwarding from
  # Windows).
  modules.gost-proxy = {
    enable = myvars.networking.services.gost-proxy.hosts.wsl-work.enable;
    instances = {
      wsl-work-socks5.port = myvars.networking.services.gost-proxy.hosts.wsl-work.ports.wsl-work-socks5;
      wsl-work-http = {
        port = myvars.networking.services.gost-proxy.hosts.wsl-work.ports.wsl-work-http;
        protocol = "http";
      };
      idols-ai-socks5 = {
        port = myvars.networking.services.gost-proxy.hosts.wsl-work.ports.idols-ai-socks5;
        chainUpstream = myvars.networking.services.gost-proxy.upstreams.idols-ai-socks5;
      };
      idols-ai-http = {
        port = myvars.networking.services.gost-proxy.hosts.wsl-work.ports.idols-ai-http;
        protocol = "http";
        chainUpstream = myvars.networking.services.gost-proxy.upstreams.idols-ai-socks5;
      };
    };
  };

  # CLIProxyAPI proxy with an offline management panel, bound to 0.0.0.0:1105.
  modules.cliproxyapi.enable = myvars.networking.services.cliproxyapi.hosts.wsl-work.enable;
  modules.cliproxyapi.port = myvars.networking.services.cliproxyapi.hosts.wsl-work.port;

  # M365 Copilot2API gateway, bound to 0.0.0.0:1104.
  modules.m365-copilot2api.enable = myvars.networking.services.m365-copilot2api.hosts.wsl-work.enable;
  modules.m365-copilot2api.port = myvars.networking.services.m365-copilot2api.hosts.wsl-work.port;

  # Agent2API gateway, bound to 0.0.0.0:1108 (API and management panel).
  modules.agent2api.enable = myvars.networking.services.agent2api.hosts.wsl-work.enable;
  modules.agent2api.port = myvars.networking.services.agent2api.hosts.wsl-work.port;

  # opencode2api gateway, bound to 0.0.0.0:1101 (API) and 0.0.0.0:1102 (WebUI).
  modules.opencode2api.enable = myvars.networking.services.opencode2api.hosts.wsl-work.enable;
  modules.opencode2api.port = myvars.networking.services.opencode2api.hosts.wsl-work.port;
  modules.opencode2api.webUiPort = myvars.networking.services.opencode2api.hosts.wsl-work.adminPort;

  # mimocode2api gateway, bound to 0.0.0.0:1103.
  modules.mimocode2api.enable = myvars.networking.services.mimocode2api.hosts.wsl-work.enable;
  modules.mimocode2api.port = myvars.networking.services.mimocode2api.hosts.wsl-work.port;

  # new-api LLM gateway, port 1100 (upstream listens on all interfaces).
  modules.new-api.enable = myvars.networking.services.new-api.hosts.wsl-work.enable;
  modules.new-api.port = myvars.networking.services.new-api.hosts.wsl-work.port;

  # Our Free Model standalone gateway, 127.0.0.1:18900 (loopback only).
  modules.our-free-model-standalone.enable =
    myvars.networking.services.our-free-model-standalone.hosts.wsl-work.enable;
  modules.our-free-model-standalone.port =
    myvars.networking.services.our-free-model-standalone.hosts.wsl-work.port;

  # Open WebUI: disabled on every host and no local instance here either;
  # the `openwebui` entry in myvars.networking.tunnels.work (local 31107 ->
  # remote 1107) is kept for a future re-enable.
  modules.open-webui.enable = myvars.networking.services.open-webui.hosts.wsl-work.enable;
  modules.open-webui.port = myvars.networking.services.open-webui.hosts.wsl-work.port;

  # Route CLI traffic through the local / LAN SOCKS proxies.
  modules.proxychains.enable = true;

  modules.port-forwarding = {
    enable = true;
    # implementation = "socat";  # default, uncomment to switch explicitly
    # The table lives in the registry: remote ports come from
    # myvars.networking.services and remote hosts from myvars.networking.endpoints,
    # so moving a gateway port is a one-line change there.
    tunnels = myvars.networking.tunnels.work;
  };

  # networking.useNetworkd = true;
  # systemd.network.enable = true;

  # systemd.network.networks."10-${iface}" = {
  #   matchConfig.Name = [iface];
  #   networkConfig = {
  #     Address = [ipv4WithMask ipv6WithMask];
  #     DNS = nameservers;
  #     DHCP = "ipv6"; # enable DHCPv6 only, so we can get a GUA.
  #     IPv6AcceptRA = true; # for Stateless IPv6 Autoconfiguraton (SLAAC)
  #     LinkLocalAddressing = "ipv6";
  #   };
  #   routes = [
  #     {
  #       Destination = "0.0.0.0/0";
  #       Gateway = mainGateway;
  #     }
  #     {
  #       Destination = "::/0";
  #       Gateway = mainGateway6;
  #       GatewayOnLink = true; # it's a gateway on local link.
  #     }
  #   ];
  #   linkConfig.RequiredForOnline = "routable";
  # };

  # conflict with feature: containerd-snapshotter
  # virtualisation.docker.storageDriver = "btrfs";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
