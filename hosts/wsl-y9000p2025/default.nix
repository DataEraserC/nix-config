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
  hostName = "y9000p2025"; # Define your hostname.
  macAddress = "random";
  inherit (myvars.networking) mainGateway mainGateway6 nameservers;
  inherit (myvars.networking.hostsAddr.${hostName}) iface ipv4 ipv6;
  ipv4WithMask = "${ipv4}/24";
  ipv6WithMask = "${ipv6}/64";

  # This machine's key in the port registry (myvars.networking.services.*.hosts):
  # the flake host name, which is not `hostName` (`y9000p2025` here).
  serviceHost = "wsl-y9000p2025";
  # One service's row on this machine - `svc "new-api"` is
  # myvars.networking.services.new-api.hosts.wsl-y9000p2025 - so the key above
  # is the only place it is spelled out.
  svc = service: myvars.networking.services.${service}.hosts.${serviceHost};

in
rec {
  imports = [
    ./netdev-mount.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix
    ./ai

    ./preservation.nix
    ./preservation-downstream.nix
    ../service-user-ids.nix
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

  # ntfy notifications on network up/down events(NM dispatcher, shared script)
  modules.network-event-notify = {
    enable = true;
    inherit hostName;
  };

  # Static service overview page (modules/nixos/base/custom/services/homepage).
  # Port, bind address and enable state come from
  # services.homepage.hosts.wsl-y9000p2025.
  modules.homepage = {
    enable = (svc "homepage").enable;
    host = (svc "homepage").host;
    port = (svc "homepage").port;
    hostKey = serviceHost;
  };

  # Oray PgyVisitor SDN client
  modules.pgy.enable = false;

  # EasyTier decentralized P2P VPN
  modules.easytier.enable = false;

  # CLIProxyAPI proxy with an offline management panel, bound to 0.0.0.0:1105.
  modules.cliproxyapi.enable = (svc "cliproxyapi").enable;
  modules.cliproxyapi.port = (svc "cliproxyapi").port;

  # M365 Copilot2API gateway, bound to 0.0.0.0:1104.
  modules.m365-copilot2api.enable = (svc "m365-copilot2api").enable;
  modules.m365-copilot2api.port = (svc "m365-copilot2api").port;

  # WebMux browser terminal server, bound to 0.0.0.0:1109 (runs as this distro's
  # login user so sessions reach its agent logins and HOME).
  modules.webmux.enable = (svc "webmux").enable;
  modules.webmux.host = (svc "webmux").host;
  modules.webmux.port = (svc "webmux").port;

  # opencode2api gateway, bound to 0.0.0.0:1101 (API) and 0.0.0.0:1102 (WebUI).
  modules.opencode2api.enable = (svc "opencode2api").enable;
  modules.opencode2api.port = (svc "opencode2api").port;
  modules.opencode2api.webUiPort = (svc "opencode2api").adminPort;

  # mimocode2api gateway, bound to 0.0.0.0:1103 (VPN interfaces only).
  modules.mimocode2api.enable = (svc "mimocode2api").enable;
  modules.mimocode2api.port = (svc "mimocode2api").port;

  # meoo2api gateway and console, bound to 0.0.0.0:1110.
  modules.meoo2api.enable = (svc "meoo2api").enable;
  modules.meoo2api.port = (svc "meoo2api").port;

  # workbuddy2api gateway and panel, bound to 0.0.0.0:1111.
  modules.workbuddy2api.enable = (svc "workbuddy2api").enable;
  modules.workbuddy2api.port = (svc "workbuddy2api").port;

  # new-api LLM gateway, port 1100 (upstream listens on all interfaces).
  modules.new-api.enable = (svc "new-api").enable;
  modules.new-api.port = (svc "new-api").port;

  # Our Free Model standalone gateway, 127.0.0.1:1107 (loopback only).
  modules.our-free-model-standalone.enable = (svc "our-free-model-standalone").enable;
  modules.our-free-model-standalone.port = (svc "our-free-model-standalone").port;

  # Open WebUI chat frontend, 0.0.0.0:1120 (shared modules.open-webui) - disabled.
  modules.open-webui.enable = (svc "open-webui").enable;
  modules.open-webui.port = (svc "open-webui").port;

  # Route CLI traffic through the local / LAN SOCKS proxies.
  modules.proxychains.enable = true;

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
