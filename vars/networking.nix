{ lib }:
rec {
  mainGateway = "192.168.0.1"; # main router
  mainGateway6 = "fe80::5"; # main router's link-local address
  # The trusted home LAN; the shared host firewall trusts this by source.
  lanCidr = "192.168.5.0/24";
  # use suzi as the default gateway
  # it's a subrouter with a transparent proxy
  proxyGateway = "192.168.0.178";
  proxyGateway6 = "fe80::8";
  # node identity must not ride the WAN /64: the ISP retires it, Cilium never refreshes it.
  clusterULA6 = "fd05:5::";
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

  # Dedicated VIP block for the k3s clusters, outside the router's DHCP pool
  # (.2-.99). One /29 per cluster, handed to kube-vip: the first usable address
  # is the control-plane API VIP, the rest are LoadBalancer service VIPs.
  k8sVip = {
    cidr = "192.168.5.192/27";
    clusters = {
      k3s-test-1 = {
        cidr = "192.168.5.192/29";
        apiVip = "192.168.5.193";
      };
      # Reserved for future clusters:
      #   .200/29  apiVip .201
      #   .208/29  apiVip .209
      #   .216/29  apiVip .217
    };
  };

  # Static LAN addresses, sorted by IPv4 ascending -- keep it sorted when adding
  # a host so the next free address is obvious. `homeOnly = true` marks an
  # address that only exists at home (the laptop's home Wi-Fi static); ssh and
  # monitoring skip those entries.
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
      # VM (retired)
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
      # Laptop: pinned on the home Wi-Fi only, by `just shoukei-home-wifi`; off
      # the home network it uses DHCP.
      iface = "wld0";
      ipv4 = "192.168.5.108";
      homeOnly = true;
    };
    k3s-test-1-worker-1 = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.111";
    };
    k3s-test-1-worker-2 = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.112";
    };
    k3s-test-1-worker-3 = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.113";
    };
    k3s-test-1-master-1 = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.114";
    };
    k3s-test-1-master-2 = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.115";
    };
    k3s-test-1-master-3 = {
      # VM
      iface = "enp2s0";
      ipv4 = "192.168.5.116";
    };
    mitsuha = {
      iface = "enp2s0"; # fake iface, it's not used by the host
      ipv4 = "192.168.5.177";
    };
    suzi = {
      iface = "enp2s0"; # fake iface, it's not used by the host
      ipv4 = "192.168.5.178";
      ipv6 = "fe80::8"; # Link-local Address, can be used as default gateway
    };
    rakushun = {
      # Orange Pi 5 - ARM, now running Armbian (not NixOS)
      # RJ45 port 1 - enP4p65s0
      # RJ45 port 2 - enP3p49s0
      iface = "enP4p65s0";
      ipv4 = "192.168.5.179";
    };
    shoryu = {
      # Homelab's physical machine (VM host)
      iface = "eno1";
      ipv4 = "192.168.5.181";
    };
    shushou = {
      # Homelab's physical machine (VM host)
      iface = "eno1";
      ipv4 = "192.168.5.182";
    };
    youko = {
      # Homelab's physical machine (VM host)
      iface = "eno1";
      ipv4 = "192.168.5.183";
    };
    # akane = {
    #   # VM (running in macOS's UTM App), using DHCP instead of static ip.
    #   iface = "enp0s1";
    #   ipv4 = "192.168.64.2";
    # };
  };

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
    # `homeOnly` entries get no alias: their address is not reachable off the
    # home LAN, so an alias would break e.g. `ssh shoukei` over Tailscale.
    extraConfig = (
      lib.attrsets.foldlAttrs (
        acc: host: val:
        if val.homeOnly or false then
          acc
        else
          acc
          + ''
            Host ${host}
              HostName ${val.ipv4}
              Port ${toString (services.ssh.hosts.${host}.port or services.ssh.defaultPort)}
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
          # the restic backup server
          youko.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEs8b3CmxM+utXZVKvJBssXBupBXvvzjHP40HcY7PSyZ root@youko";
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
  # `peers`, `easytier.instances` and `genericHosts` below: every overlay
  # address is declared exactly once, here.
  #
  # Each machine instance ("device") declares the hostname class it uses
  # (`class`), optionally the hostName of the NixOS host running on it (the
  # key for host-name-addressed views like `easytier.instances`), and one
  # attribute per overlay network, structured as IP + prefix length:
  #   addrs.<net> = { ip; prefixLength; iface?; }
  # (`iface` is only needed where something addresses the NIC itself; the
  # network follows from ip & prefixLength, e.g. 10.126.126.150/24 belongs to
  # 10.126.126.0/24.) `genericHosts` renders one
  #   <device>_<class>_<network>.mayuri.org
  # line per declared address, so growing the matrix stays data-only:
  #   - new device (e.g. another wsl box): add an entry here;
  #   - new network (easytier, oray, ...): add `addrs.<net>` to the devices
  #     that have one, and optionally extend `networkOrder` to position it;
  #   - new naming scheme: pick another `class` token for the device.
  # ==========================================================================
  devices = {
    # --- remote android devices, driven through the Termux CLI ---
    mondrian = {
      class = "android_cli";
      addrs = {
        zerotier = {
          ip = "10.147.20.151";
          prefixLength = 24;
        };
        tailscale = {
          ip = "100.95.92.151";
          prefixLength = 32;
        };
      };
    };
    pstar = {
      class = "android_cli";
      addrs = {
        zerotier = {
          ip = "10.147.20.153";
          prefixLength = 24;
        };
        tailscale = {
          ip = "100.95.92.153";
          prefixLength = 32;
        };
      };
    };
    infiniti = {
      class = "android_cli";
      addrs = {
        zerotier = {
          ip = "10.147.20.154";
          prefixLength = 24;
        };
        tailscale = {
          ip = "100.95.92.154";
          prefixLength = 32;
        };
        # easytier on the android side, runs outside this flake.
        easytier = {
          ip = "10.126.126.154";
          prefixLength = 24;
        };
      };
    };

    # --- this machine: NixOS on the y9000p2025 laptop ---
    y9000p2025 = {
      class = "nixos";
      hostName = "ai"; # hosts/idols-ai, easytier is managed by easytier.nix
      addrs = {
        zerotier = {
          ip = "10.147.20.150";
          prefixLength = 24;
          iface = "zt5u4z6wb4";
        };
        tailscale = {
          ip = "100.95.92.150";
          prefixLength = 32;
          iface = "tailscale0";
        };
        easytier = {
          ip = "10.126.126.150";
          prefixLength = 24;
          iface = "easytier0";
        };
      };
    };

    # --- WSL distro on the work laptop ---
    work = {
      class = "wsl";
      hostName = "work"; # hosts/wsl-work, easytier is managed by easytier.nix
      addrs = {
        easytier = {
          ip = "10.126.126.170";
          prefixLength = 24;
        };
      };
    };
  };

  # Key of this machine inside `devices`: its group is rendered last
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

  # ==========================================================================
  # services - the port registry, keyed by (service_name x host).
  #
  # Scope (agreed): only what is (a) managed by a NixOS module of this flake
  # and (b) reachable from OUTSIDE its host - services listening on the
  # overlay / LAN / 0.0.0.0 - gets an entry here, plus the virtual network
  # registrations further down in this file (`devices`, `endpoints`,
  # `easytier.instances`). Not registered for now: loopback-only listeners (the
  # dsh GUI on 127.0.0.1:9900, proxychains' local client ports) and services
  # no NixOS module drives (adb, the LAN proxies, opencode, rdp, termux sshd)
  # - those keep literal ports where they are used, e.g. in `tunnels.work`.
  #
  # The port of such a service is declared once, instead of as a literal
  # scattered over module configs, host tunnel tables and ssh settings.
  #
  # Shape - every service is a (service x host) matrix:
  #   hosts.<machine> = { enable, host, port, ... }
  #                 one row per machine that runs (or deliberately does not
  #                 run) the service. The values are uniform across machines
  #                 today, but the row is the reserved spot for divergence: a
  #                 single machine may later flip its switch or move to
  #                 another port or bind address without touching siblings.
  #     enable      THE on/off state of the service on that machine, wired
  #                 into `modules.<name>.enable` - flipping the registry flips
  #                 the host (there is no `enablePath` indirection anymore).
  #                 Absence of a row = the service is not registered there.
  #     host        BIND address the service listens on - 0.0.0.0 for a wide
  #                 bind, 127.0.0.1 for loopback - never a machine name.
  #                 Consumed as `modules.<name>.host` where the module has such
  #                 an option (sub-store), so wiring reads:
  #                   modules.sub-store = {
  #                     enable = myvars.networking.services.sub-store.hosts.idols-ai.enable;
  #                     host = myvars.networking.services.sub-store.hosts.idols-ai.host;
  #                   };
  #     port        primary listen port; secondary listeners keep their own key
  #                 (adminPort for the opencode2api WebUI, s3Port for alist,
  #                 frontendPort for the sub-store panel), gost-proxy carries
  #                 a per-machine `ports` set of its listener names instead
  #   defaultPort   `ssh` only: the stock sshd port for machines without a row;
  #                 ssh rows carry no `enable` - modules/nixos/base/ssh.nix
  #                 turns sshd on for every NixOS machine (base-wide)
  #
  # Consumed by:
  #   - host wiring of `options.modules.<name>` in the hosts/* files: each
  #     host reads its own `hosts.<machine>` row straight from here - the
  #     enable state into `modules.<name>.enable`, the port(s) into the port
  #     options (both are required module options, no defaults);
  #   - `tunnels.work` below, applied on wsl-work by modules.port-forwarding
  #     (every entry targets the laptop, so it reads the `idols-ai` rows);
  #   - the ssh_config fold above (`services.ssh`), one Port per Host block:
  #     that machine's row when it has one, else `defaultPort`;
  #   - the port catalog page, which renders this attribute set directly -
  #     enable state, bind address and ports per machine - so enablement is
  #     a single source of truth in the registry.
  # ==========================================================================
  services = {
    # --- LLM gateways (1100..1110); rows per machine that runs them ---
    new-api = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 1100;
        };
        wsl-y9000p2025 = {
          enable = true;
          host = "0.0.0.0";
          port = 1100;
        };
        wsl-work = {
          enable = true;
          host = "0.0.0.0";
          port = 1100;
        };
      };
    };
    opencode2api = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 1101;
          adminPort = 1102;
        };
        wsl-y9000p2025 = {
          enable = true;
          host = "0.0.0.0";
          port = 1101;
          adminPort = 1102;
        };
        wsl-work = {
          enable = true;
          host = "0.0.0.0";
          port = 1101;
          adminPort = 1102;
        };
      };
    };
    mimocode2api = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 1103;
        };
        wsl-y9000p2025 = {
          enable = true;
          host = "0.0.0.0";
          port = 1103;
        };
        wsl-work = {
          enable = true;
          host = "0.0.0.0";
          port = 1103;
        };
      };
    };
    m365-copilot2api = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 1104;
        };
        wsl-y9000p2025 = {
          enable = true;
          host = "0.0.0.0";
          port = 1104;
        };
        wsl-work = {
          enable = true;
          host = "0.0.0.0";
          port = 1104;
        };
      };
    };
    cliproxyapi = {
      hosts = {
        idols-ai = {
          enable = false;
          host = "0.0.0.0";
          port = 1105;
        };
        wsl-y9000p2025 = {
          enable = false;
          host = "0.0.0.0";
          port = 1105;
        };
        wsl-work = {
          enable = false;
          host = "0.0.0.0";
          port = 1105;
        };
      };
    };
    omniroute = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 1106;
        };
      };
    };
    open-webui = {
      hosts = {
        idols-ai = {
          enable = false;
          host = "0.0.0.0";
          port = 1107;
        };
        wsl-y9000p2025 = {
          enable = false;
          host = "0.0.0.0";
          port = 1107;
        };
        wsl-work = {
          enable = false;
          host = "0.0.0.0";
          port = 1107;
        };
      };
    };
    alist = {
      hosts = {
        # the optional S3-mapping listener (settings.s3, off by default)
        # rides on s3Port
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 5244;
          s3Port = 5246;
        };
      };
    };

    # --- subscription manager, fronted by Caddy (base/custom/sub-store) ---
    # The one service whose bind address a module option consumes directly
    # (`modules.sub-store.host`, see the shape notes above); its enable is
    # wired from the row the same way. port / frontendPort document what
    # idols-ai deploys for the catalog - the module defaults apply, and dae
    # pins the backend on 127.0.0.1:24500.
    sub-store = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 24500;
          frontendPort = 24501;
        };
      };
    };

    # --- authenticated SOCKS5 proxy (modules/nixos/base/custom/gost-proxy.nix)
    # The same instance names are used on several hosts, so each row lists
    # the instances that machine declares; ports, not enablement, live here.
    gost-proxy = rec {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          ports = {
            proxy = 1080; # direct listener; also wsl-work's chained hop
          };
        };
        wsl-work = {
          enable = true;
          host = "0.0.0.0";
          ports = {
            proxy = 1080; # direct listener, same number as idols-ai today
            idols-ai = 31080; # wsl-work only: chains through idols-ai's proxy
          };
        };
      };
      # upstream of the `idols-ai` instance, derived instead of restated so
      # the two ports can never drift apart
      chainUpstream = "${endpoints.y9000p2025.easytier}:${toString hosts.idols-ai.ports.proxy}";
    };

    # --- sshd; the per-host listen ports live here, not on hostsAddr ---
    ssh = {
      # no `enable` on purpose: modules/nixos/base/ssh.nix turns sshd on for
      # every NixOS machine (base-wide), so the rows below carry host/port
      # only
      # stock sshd port for every hostsAddr machine without its own row below
      defaultPort = 22;
      # keyed by hostsAddr key (that is how the ssh_config fold looks rows up):
      # the work laptop runs sshd on 8022 instead of the stock 22, and
      # `wsl-work` aliases `work` (same machine), so it reuses that row instead
      # of restating it; `idols-ai` / `wsl-y9000p2025` pin this laptop's stock
      # 22 explicitly, the remaining keys (VMs, SBCs) inherit defaultPort.
      hosts = rec {
        idols-ai = {
          host = "0.0.0.0";
          port = 22;
        };
        wsl-y9000p2025 = {
          host = "0.0.0.0";
          port = 22;
        };
        work = {
          host = "0.0.0.0";
          port = 8022;
        };
        wsl-work = work;
      };
    };
  };

  # endpoints.<device>.<network> - the overlay ip of every device on every
  # network it joined, `devices` flattened for consumers that only need an
  # address (tunnel targets, chainUpstream, ...).
  endpoints = lib.mapAttrs (_: dev: lib.mapAttrs (_: addr: addr.ip) dev.addrs) devices;

  # ==========================================================================
  # tunnels.work - the port-forward table applied on `work` (wsl-work) by
  # modules.port-forwarding. Remote hosts come from `endpoints` and remote
  # ports from `services`, so moving a gateway port stays a one-line edit in
  # the registry; local ports are `work`'s own addressing (3xxxx = forwarded
  # from the laptop, 4xxxx = from infiniti) and belong to this table.
  # ==========================================================================
  tunnels.work = [
    # idols-ai / y9000p2025 (10.126.126.150) - 3xxxx range
    {
      name = "new-api";
      localPort = 31100;
      remoteHost = endpoints.y9000p2025.easytier;
      remotePort = services.new-api.hosts.idols-ai.port;
    }
    {
      name = "opencode2api";
      localPort = 31101;
      remoteHost = endpoints.y9000p2025.easytier;
      remotePort = services.opencode2api.hosts.idols-ai.port;
    }
    {
      name = "opencode2api-management-center";
      localPort = 31102;
      remoteHost = endpoints.y9000p2025.easytier;
      remotePort = services.opencode2api.hosts.idols-ai.adminPort;
    }
    {
      name = "mimocode2api";
      localPort = 31103;
      remoteHost = endpoints.y9000p2025.easytier;
      remotePort = services.mimocode2api.hosts.idols-ai.port;
    }
    {
      name = "M365-Copilot2API";
      localPort = 31104;
      remoteHost = endpoints.y9000p2025.easytier;
      remotePort = services.m365-copilot2api.hosts.idols-ai.port;
    }
    {
      name = "cliproxyapimanagementcenter";
      localPort = 31105;
      remoteHost = endpoints.y9000p2025.easytier;
      remotePort = services.cliproxyapi.hosts.idols-ai.port;
    }
    # {
    #   name = "omniroute";
    #   localPort = 31106;
    #   remoteHost = endpoints.y9000p2025.easytier;
    #   remotePort = services.omniroute.hosts.idols-ai.port;
    # }
    {
      name = "openwebui";
      localPort = 31107;
      remoteHost = endpoints.y9000p2025.easytier;
      remotePort = services.open-webui.hosts.idols-ai.port;
    }
    # dsh needs the ssh forward to work at all (its security checks reject
    # plain TCP), so the tunnel must speak ssh - kept for a future re-enable:
    # {
    #   name = "dsh";
    #   localPort = 33080;
    #   remoteHost = endpoints.y9000p2025.easytier;
    #   remotePort = 3080;
    # }
    # rdp / opencode / the LAN proxy on the laptop are not driven by a NixOS
    # module, so they stay unregistered (registry scope) and carry literals.
    {
      name = "rdp";
      localPort = 33389;
      remoteHost = endpoints.y9000p2025.easytier;
      remotePort = 3389;
    }
    {
      name = "ssh";
      localPort = 30022;
      remoteHost = endpoints.y9000p2025.easytier;
      remotePort = services.ssh.hosts.idols-ai.port;
    }
    {
      name = "opencode";
      localPort = 34096;
      remoteHost = endpoints.y9000p2025.easytier;
      remotePort = 4096;
    }
    {
      name = "y9000p2025-proxy";
      localPort = 37890;
      remoteHost = endpoints.y9000p2025.easytier;
      remotePort = 7897;
    }
    # apatch-infiniti (10.126.126.154) - 4xxxx range; adb, the device's SOCKS
    # proxy and the Termux sshd run outside this flake, so their ports are
    # literals until a NixOS module owns them.
    {
      name = "adb";
      localPort = 45555;
      remoteHost = endpoints.infiniti.easytier;
      remotePort = 5555;
    }
    {
      name = "infiniti-proxy";
      localPort = 42080;
      remoteHost = endpoints.infiniti.easytier;
      remotePort = 2080;
    }
    {
      name = "termux-ssh";
      localPort = 40022;
      remoteHost = endpoints.infiniti.easytier;
      remotePort = 8022;
    }
  ];

  # Endpoints of the other devices on the overlay networks, keyed by device
  # name, so hosts can reference them symbolically (e.g. auto-shutdown's
  # channel probes) instead of hardcoding IPs. Derived from `devices`
  # above: device → { network = ip; }.
  peers = lib.mapAttrs (_: dev: lib.mapAttrs (_: addr: addr.ip) dev.addrs) (
    removeAttrs devices [ selfDevice ]
  );

  # EasyTier - decentralized P2P VPN overlay network. Network credentials are
  # stored as agenix secrets (easytier.env) and injected via environmentFiles
  # in the easytier module; the addresses themselves are not duplicated here:
  # `instances` is derived from `devices`, keyed by the hostName each
  # device declares, because easytier.nix looks up `instances.${hostName}`
  # for the running host. Devices without easytier or without a hostName
  # (e.g. the android side) are skipped.
  easytier.instances = lib.listToAttrs (
    lib.concatMap (
      dev:
      lib.optional (dev ? hostName && dev.addrs ? easytier) {
        name = dev.hostName;
        value = "${dev.addrs.easytier.ip}/${toString dev.addrs.easytier.prefixLength}";
      }
    ) (lib.attrValues devices)
  );

  # /etc/hosts entries for the overlay endpoints: the devices × networks
  # cross product of `devices`, one group per device - static entries
  # first, remote devices alphabetically, this machine's group last. Groups
  # are separated by a blank line and the payload ends with a newline.
  genericHosts =
    let
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
          map (net: "${dev.addrs.${net}.ip} ${device}_${dev.class}_${net}.mayuri.org") (netNames dev)
        );
      remoteGroups = lib.mapAttrsToList deviceGroup (removeAttrs devices [ selfDevice ]);
      groups = staticHosts ++ remoteGroups ++ [ (deviceGroup selfDevice devices.${selfDevice}) ];
    in
    lib.concatStringsSep "\n\n" groups + "\n";
}
