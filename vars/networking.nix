{ lib }:
rec {
  mainGateway = "192.168.0.1"; # main router
  mainGateway6 = "fe80::5"; # main router's link-local address
  # use suzi as the default gateway
  # it's a subrouter with a transparent proxy
  proxyGateway = "192.168.0.178";
  proxyGateway6 = "fe80::8";
  nameservers = [
    # IPv4
    "119.29.29.29" # DNSPod https://www.dnspod.cn/Products/publicdns
    "223.5.5.5" # AliDNS
    "1.1.1.1" # Cloudflare https://one.one.one.one/dns/
    # IPv6
    "2402:4e00::" # DNSPod
    "2400:3200::1" # Alidns
    "2606:4700:4700::1111" # Cloudflare
  ];
  prefixLength = 24;

  hostsAddr = rec {
    # ============================================
    # Homelab's Physical Machines (KubeVirt Nodes)
    # ============================================
    kubevirt-shoryu = {
      iface = "eno1";
      ipv4 = "192.168.5.181";
    };
    kubevirt-shushou = {
      iface = "eno1";
      ipv4 = "192.168.5.182";
    };
    kubevirt-youko = {
      iface = "eno1";
      ipv4 = "192.168.5.183";
    };

    # ============================================
    # Other VMs and Physical Machines
    # ============================================
    y9000p2025 = {
      # Laptop - physical home network interface
      iface = "wlp130s0";
      ipv4 = "192.168.2.150";
      ipv6 = "fe80::150"; # Link-local Address
    };
    idols-ai = y9000p2025;
    ai = y9000p2025;
    wsl-y9000p2025 = y9000p2025;
    work = {
      # Work Laptop - physical home network interface
      iface = "wlp130s0";
      ipv4 = "192.168.2.150";
      ipv6 = "fe80::150"; # Link-local Address
    };
    wsl-work = work;
    # akane = {
    #   # VM (running in macOS's UTM App), using DHCP instead of static ip.
    #   iface = "enp0s1";
    #   ipv4 = "192.168.64.2";
    # };
    aquamarine = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.101";
    };
    ruby = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.102";
    };
    kana = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.103";
    };
    nozomi = {
      # LicheePi 4A's wireless interface - RISC-V
      iface = "wlan0";
      ipv4 = "192.168.5.104";
    };
    yukina = {
      # LicheePi 4A's wireless interface - RISC-V
      iface = "wlan0";
      ipv4 = "192.168.5.105";
    };
    chiaya = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.106";
    };
    suzu = {
      # Orange Pi 5 - ARM
      iface = "end1";
      ipv4 = "192.168.5.107";
    };
    shoukei = {
      # Apple M2 + NixOS
      # Used only when at home
      iface = "wlan0";
      ipv4 = "192.168.5.108";
      ipv6 = "fe80::11"; # Link-local Address
    };
    rakushun = {
      # Orange Pi 5 - ARM
      # RJ45 port 1 - enP4p65s0
      # RJ45 port 2 - enP3p49s0
      iface = "enP4p65s0";
      ipv4 = "192.168.5.179";
    };
    suzi = {
      iface = "enp2s0"; # fake iface, it's not used by the host
      ipv4 = "192.168.5.178";
      ipv6 = "fe80::8"; # Link-local Address, can be used as default gateway
    };
    mitsuha = {
      iface = "enp2s0"; # fake iface, it's not used by the host
      ipv4 = "192.168.5.177";
    };

    # ============================================
    # Kubernetes Clusters
    # ============================================
    k3s-prod-1-master-1 = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.108";
    };
    k3s-prod-1-master-2 = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.109";
    };
    k3s-prod-1-master-3 = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.110";
    };
    k3s-prod-1-worker-1 = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.111";
    };
    k3s-prod-1-worker-2 = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.112";
    };
    k3s-prod-1-worker-3 = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.113";
    };

    k3s-test-1-master-1 = {
      # KubeVirt VM
      iface = "enp2s0";
      ipv4 = "192.168.5.114";
    };
    k3s-test-1-master-2 = {
      # KubeVirt VM
      iface = "enp2s0";
      ipv4 = "192.168.5.115";
    };
    k3s-test-1-master-3 = {
      # KubeVirt VM
      iface = "enp2s0";
      ipv4 = "192.168.5.116";
    };
  };

  # VPN interfaces grouped by physical device (not in hostsAddr since they are virtual overlays)
  vpnInterfaces = {
    y9000p2025 = {
      zerotier = {
        iface = "zt5u4z6wb4";
        ipv4 = "10.147.20.150";
        ipv6 = "fe80::150";
      };
      tailscale = {
        iface = "tailscale0";
        ipv4 = "100.95.92.150";
        ipv6 = "fe80::150";
      };
    };
  };

  # EasyTier - decentralized P2P VPN overlay network addresses
  # NOTE: network_name and network_secret are stored as agenix secrets (easytier.env)
  # and injected via environmentFiles in the easytier module.
  easytier = rec {
    instances = rec {
      idols-ai = "10.126.126.150/24";
      ai = idols-ai;
      wsl-work = "10.126.126.170/24";
      work = wsl-work;
      apatch-infiniti = "10.126.126.154/24";
      infiniti = apatch-infiniti;
    };

    # The same addresses without their CIDR suffix, for consumers that need a
    # plain IP (e.g. /etc/hosts entries in `genericHosts`, ping probes).
    ips = lib.mapAttrs (_: addr: lib.head (lib.splitString "/" addr)) instances;
  };

  hostsInterface = lib.attrsets.mapAttrs (key: val: {
    interfaces."${val.iface}" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          inherit prefixLength;
          address = val.ipv4;
        }
      ];
    };
  }) hostsAddr;

  ssh = {
    # define the host alias for remote builders
    # this config will be written to /etc/ssh/ssh_config
    #
    # Config format:
    #   Host —  given the pattern used to match against the host name given on the command line.
    #   HostName — specify nickname or abbreviation for host
    #   IdentityFile — the location of your SSH key authentication file for the account.
    # Format in details:
    #   https://www.ssh.com/academy/ssh/config
    extraConfig = (
      lib.attrsets.foldlAttrs (
        acc: host: val:
        acc
        + ''
          Host ${host}
            HostName ${val.ipv4}
            Port 22
        ''
      ) "" hostsAddr
    );

    # this config will be written to /etc/ssh/ssh_known_hosts
    knownHosts =
      # Update only the values of the given attribute set.
      #
      #   mapAttrs
      #   (name: value: ("bar-" + value))
      #   { x = "a"; y = "b"; }
      #     => { x = "bar-a"; y = "bar-b"; }
      lib.attrsets.mapAttrs
        (host: value: {
          hostNames = [ host ] ++ (lib.optional (hostsAddr ? host) hostsAddr.${host}.ipv4);
          publicKey = value.publicKey;
        })
        {
          # Define the root user's host key for remote builders, so that nix can verify all the remote builders

          aquamarine.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEOXFhFu9Duzp6ZBE288gDZ6VLrNaeWL4kDrFUh9Neic root@aquamarine";
          # ruby.publicKey = "";
          # kana.publicKey = "";

          # ==================================== Other SSH Service's Public Key =======================================

          # https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
          "github.com".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        };
  };
  # ==========================================================================
  # Overlay endpoints - devices × networks, the single source of truth behind
  # `peers` and `genericHosts` below.
  #
  # Each device declares the hostname class it uses (`class`) plus one
  # attribute per overlay network it has an address on. `genericHosts` renders
  #   <device>_<class>_<network>.mayuri.org
  # for every declared address, so growing the matrix stays data-only:
  #   - new device (e.g. another wsl box): add an entry here;
  #   - new network (easytier, oray, ...): add `addrs.<net>` to the devices
  #     that have one, and optionally extend `networkOrder` to position it;
  #   - new naming scheme: pick another `class` token for the device.
  # ==========================================================================
  overlayDevices = {
    # --- remote android devices, driven through the Termux CLI ---
    mondrian = {
      class = "android_cli";
      addrs = {
        zerotier = "10.147.20.151";
        tailscale = "100.95.92.151";
      };
    };
    pstar = {
      class = "android_cli";
      addrs = {
        zerotier = "10.147.20.153";
        tailscale = "100.95.92.153";
      };
    };
    infiniti = {
      class = "android_cli";
      addrs = {
        zerotier = "10.147.20.154";
        tailscale = "100.95.92.154";
        # easytier runs on this device as the `apatch-infiniti` instance.
        easytier = easytier.ips.infiniti;
      };
    };

    # --- this machine: NixOS on the y9000p2025 laptop ---
    y9000p2025 = {
      class = "nixos";
      addrs = {
        zerotier = vpnInterfaces.y9000p2025.zerotier.ipv4;
        tailscale = vpnInterfaces.y9000p2025.tailscale.ipv4;
        # easytier instance of hosts/idols-ai (hostName "ai").
        easytier = easytier.ips.ai;
      };
    };

    # --- WSL distro on the work laptop ---
    work = {
      class = "wsl";
      addrs = {
        easytier = easytier.ips.work;
      };
    };
  };

  # Key of this machine inside `overlayDevices`: its group is rendered last
  # in `genericHosts` and it is excluded from the derived `peers` view.
  selfDevice = "y9000p2025";

  # Order of the networks inside one device group of `genericHosts`;
  # networks not listed here (future ones) are appended alphabetically.
  networkOrder = [
    "zerotier"
    "tailscale"
    "easytier"
    "oray"
  ];

  # /etc/hosts entries that belong to no overlay device, rendered first.
  staticHosts = [ "155.248.179.129 oracle_ubuntu_1.mayuri.org" ];

  # Endpoints of the other devices on the overlay networks, keyed by device
  # name, so hosts can reference them symbolically (e.g. auto-shutdown's
  # channel probes) instead of hardcoding IPs. Derived from `overlayDevices`
  # above: device → { network = bare IP; }, keeping hosts-file entries and
  # these names from drifting apart.
  peers = lib.mapAttrs (_: dev: dev.addrs) (removeAttrs overlayDevices [ selfDevice ]);

  # /etc/hosts entries for the overlay endpoints: the devices × networks
  # cross product of `overlayDevices`, one group per device - static entries
  # first, remote devices alphabetically, this machine's group last. Groups
  # are separated by a blank line and the payload ends with a newline.
  genericHosts =
    let
      # tolerate CIDR-form addresses ("10.126.126.154/24").
      bareIp = addr: lib.head (lib.splitString "/" addr);
      netNames =
        dev:
        let
          present = lib.attrNames dev.addrs;
        in
        # known networks in canonical order first, unknown ones appended.
        lib.filter (net: lib.elem net present) networkOrder
        ++ lib.filter (net: !(lib.elem net networkOrder)) present;
      deviceGroup =
        device: dev:
        lib.concatStringsSep "\n" (
          map (net: "${bareIp dev.addrs.${net}} ${device}_${dev.class}_${net}.mayuri.org") (netNames dev)
        );
      remoteGroups = lib.mapAttrsToList deviceGroup (removeAttrs overlayDevices [ selfDevice ]);
      groups = staticHosts ++ remoteGroups ++ [ (deviceGroup selfDevice overlayDevices.${selfDevice}) ];
    in
    lib.concatStringsSep "\n\n" groups + "\n";
}
