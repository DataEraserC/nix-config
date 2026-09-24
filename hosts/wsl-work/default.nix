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

  # ntfy notifications on network up/down events(NM dispatcher, shared script)
  modules.network-event-notify = {
    enable = true;
    inherit hostName;
  };

  # Oray PgyVisitor SDN client
  modules.pgy.enable = true;

  # EasyTier decentralized P2P VPN
  modules.easytier.enable = true;

  # CLIProxyAPI proxy with an offline management panel, bound to 0.0.0.0:8317.
  modules.cliproxyapi.enable = false;

  # M365 Copilot2API gateway, bound to 0.0.0.0:4141.
  modules.m365-copilot2api.enable = true;

  # opencode2api gateway, bound to 0.0.0.0:4142 (API) and 0.0.0.0:4143 (WebUI).
  modules.opencode2api.enable = true;

  # mimocode2api gateway, bound to 0.0.0.0:4144.
  modules.mimocode2api.enable = true;

  # new-api LLM gateway, bound to 0.0.0.0:3000.
  modules.new-api.enable = true;

  # Route CLI traffic through the local / LAN SOCKS proxies.
  modules.proxychains.enable = true;

  modules.port-forwarding = {
    enable = true;
    # implementation = "socat";  # default, uncomment to switch explicitly
    tunnels = [
      # idols-ai (10.126.126.150) - 3xxxx range
      {
        name = "cliproxyapimanagementcenter";
        localPort = 38317;
        remoteHost = "10.126.126.150";
        remotePort = 8317;
      }
      {
        name = "new-api";
        localPort = 33000;
        remoteHost = "10.126.126.150";
        remotePort = 3000;
      }
      {
        name = "M365-Copilot2API";
        localPort = 34141;
        remoteHost = "10.126.126.150";
        remotePort = 4141;
      }
      {
        name = "opencode2api";
        localPort = 34142;
        remoteHost = "10.126.126.150";
        remotePort = 4142;
      }
      {
        name = "opencode2api-management-center";
        localPort = 34143;
        remoteHost = "10.126.126.150";
        remotePort = 4143;
      }
      {
        name = "openwebui";
        localPort = 38080;
        remoteHost = "10.126.126.150";
        remotePort = 8080;
      }
      # dsh 有很强的安全保护，需要通过ssh转发，否则很多功能不生效
      # {
      #   name = "dsh";
      #   localPort = 33080;
      #   remoteHost = "10.126.126.150";
      #   remotePort = 3080;
      # }
      {
        name = "rdp";
        localPort = 33389;
        remoteHost = "10.126.126.150";
        remotePort = 3389;
      }
      {
        name = "ssh";
        localPort = 30022;
        remoteHost = "10.126.126.150";
        remotePort = 22;
      }
      {
        name = "opencode";
        localPort = 34096;
        remoteHost = "10.126.126.150";
        remotePort = 4096;
      }
      {
        name = "y9000p2025-proxy";
        localPort = 37890;
        remoteHost = "10.126.126.150";
        remotePort = 7897;
      }
      # apatch-infiniti (10.126.126.154) - 4xxxx range
      {
        name = "adb";
        localPort = 45555;
        remoteHost = "10.126.126.154";
        remotePort = 5555;
      }
      {
        name = "infiniti-proxy";
        localPort = 42080;
        remoteHost = "10.126.126.154";
        remotePort = 2080;
      }
      {
        name = "termux-ssh";
        localPort = 40022;
        remoteHost = "10.126.126.154";
        remotePort = 8022;
      }
    ];
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
