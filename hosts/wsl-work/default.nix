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
  # registry (myvars.networking.services.ssh.ports.work). The generated
  # client config (/etc/ssh/ssh_config) reads the same table, so `ssh work` /
  # `ssh wsl-work` dial 8022 too.
  services.openssh.ports = [ myvars.networking.services.ssh.ports.work ];

  # ntfy notifications on network up/down events(NM dispatcher, shared script)
  modules.network-event-notify = {
    enable = true;
    inherit hostName;
  };

  # Oray PgyVisitor SDN client
  modules.pgy.enable = true;

  # EasyTier decentralized P2P VPN
  modules.easytier.enable = true;

  # Authenticated SOCKS5 proxies (shared modules/nixos/base/custom/gost-proxy.nix):
  # - 1080: direct proxy for reaching intranet/overlay resources via this host;
  # - 31080: chained through idols-ai's 1080 (easytier 10.126.126.150), so a
  #   client of 31080 resolves destinations ON idols-ai - notably its loopback
  #   127.0.0.1:9900 where the dsh GUI listens. Same agenix credentials
  #   (gost-proxy.auth) on both hosts, so one client config fits both ports.
  # The host firewall is disabled here, so both ports are reachable wherever
  # this host is (easytier mesh, WSL localhost forwarding from Windows).
  modules.gost-proxy = {
    enable = true;
    instances = {
      proxy.port = myvars.networking.services.gost-proxy.ports.proxy;
      idols-ai = {
        port = myvars.networking.services.gost-proxy.ports.idols-ai;
        chainUpstream = myvars.networking.services.gost-proxy.chainUpstream;
      };
    };
  };

  # CLIProxyAPI proxy with an offline management panel, bound to 0.0.0.0:1105.
  modules.cliproxyapi.enable = false;
  modules.cliproxyapi.port = myvars.networking.services.cliproxyapi.port;

  # M365 Copilot2API gateway, bound to 0.0.0.0:1104.
  modules.m365-copilot2api.enable = true;
  modules.m365-copilot2api.port = myvars.networking.services.m365-copilot2api.port;

  # opencode2api gateway, bound to 0.0.0.0:1101 (API) and 0.0.0.0:1102 (WebUI).
  modules.opencode2api.enable = true;
  modules.opencode2api.port = myvars.networking.services.opencode2api.port;
  modules.opencode2api.webUiPort = myvars.networking.services.opencode2api.adminPort;

  # mimocode2api gateway, bound to 0.0.0.0:1103.
  modules.mimocode2api.enable = true;
  modules.mimocode2api.port = myvars.networking.services.mimocode2api.port;

  # new-api LLM gateway, port 1100 (upstream listens on all interfaces).
  modules.new-api.enable = true;
  modules.new-api.port = myvars.networking.services.new-api.port;

  # Open WebUI: disabled on every host and no local instance here either;
  # the `openwebui` entry in myvars.networking.tunnels.work (local 31107 ->
  # remote 1107) is kept for a future re-enable.
  modules.open-webui.enable = false;
  modules.open-webui.port = myvars.networking.services.open-webui.port;

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
