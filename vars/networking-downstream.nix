# Downstream-only network data, deep-merged over vars/networking.nix by
# vars/default.nix (lib.recursiveUpdate). Keep vars/networking.nix
# byte-identical to upstream: a merge conflict there is the signal to read the
# upstream change and port it into this overlay (same workflow as
# secrets/nixos.nix -> secrets/nixos_agenix.nix).
{ lib, upstream }:
rec {
  # downstream LAN uses 192.168.0.0/24 for the gateways
  mainGateway = "192.168.0.1"; # main router
  proxyGateway = "192.168.0.178";

  hostsAddr = rec {
    # Only the downstream-only machines are listed here; everything upstream
    # knows (the VM hosts `shoryu` / `shushou` / `youko` on 192.168.5.181-183
    # included) is merged in from vars/networking.nix - do not restate it, or
    # the copy goes stale the next time upstream renames something (a stale
    # `kubevirt-shoryu` duplicate lived here for exactly that reason).
    y9000p2025 = {
      # Laptop - physical home network interface
      iface = "wlp130s0";
      ipv4 = "192.168.2.150";
      ipv6 = "fe80::150"; # Link-local Address
      # The address above is not configured on this interface: NetworkManager
      # uses DHCP and the reachable channels are localhost / the overlay
      # interfaces. Upstream's `homeOnly` makes the monitoring module skip the
      # LAN-bound exporters (node, smartctl) and the ssh alias for this host;
      # without it both exporters bind to a nonexistent address and fail at
      # activation.
      homeOnly = true;
    };
    idols-ai = y9000p2025;
    ai = y9000p2025;
    wsl-y9000p2025 = y9000p2025;
    work = {
      # Work Laptop - physical home network interface
      iface = "wlp130s0";
      ipv4 = "192.168.2.150";
      ipv6 = "fe80::150"; # Link-local Address
      # Same shape as `y9000p2025`: this WSL host has no such address on its
      # interface, so upstream's LAN-bound exporters would fail to bind. The
      # flag also drops the dead `ssh work` / `ssh wsl-work` aliases.
      homeOnly = true;
    };
    wsl-work = work;
  };

  # override of the upstream fold: downstream hosts carry non-22 sshd ports
  # declared in services.ssh below, so the Port line has to look them up.
  ssh.extraConfig = (
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
    ) "" (upstream.hostsAddr // hostsAddr)
  );

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
  # dsh GUI on 127.0.0.1:3080, proxychains' local client ports) and services
  # no NixOS module drives (adb, the LAN proxies, opencode, rdp, termux sshd)
  # - those keep literal ports where they are used, e.g. in `tunnels.work`.
  #
  # The port of such a service is declared once, instead of as a literal
  # scattered over module configs, host tunnel tables and ssh settings.
  #
  # Order - entries are sorted by primary port ascending (`ssh` leads with its
  # stock 22, gost-proxy sorts by its lowest listener), and a new service is
  # inserted at its port position, so the next free slot in a series is obvious
  # the way `hostsAddr` stays sorted by IPv4. Enable state and secondary
  # listeners do not move an entry: a disabled row keeps its slot.
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
  #                 an option (sub-store). Each host file binds its own key once
  #                 (`svc` in its let block), so wiring reads:
  #                   modules.sub-store = {
  #                     enable = (svc "sub-store").enable;
  #                     host = (svc "sub-store").host;
  #                   };
  #     port        primary listen port; secondary listeners keep their own key
  #                 (adminPort for the opencode2api WebUI, s3Port for alist,
  #                 frontendPort for the sub-store panel), gost-proxy carries
  #                 a per-machine `ports` set of its listener names instead
  #   defaultPort   `ssh` only: the stock sshd port for machines without a row;
  #                 ssh rows carry no `enable` - modules/nixos/base/ssh.nix
  #                 turns sshd on for every NixOS machine (base-wide)
  #   catalog       optional page metadata. Its presence opts the service into
  #                 the service overview page
  #                 (modules/nixos/base/custom/services/homepage); services
  #                 without it are not listed. Fields:
  #                   protocol  URL scheme of the listed endpoint (default http)
  #                   portKey   dotted path into the host row when the listed
  #                             endpoint is not `port` (e.g. "adminPort",
  #                             "ports.console", "frontendPort")
  #                   bindKey   dotted path into the host row when the listed
  #                             endpoint does not bind to `host` (e.g. acb's
  #                             console on `exposeHost`)
  #                   path      URL path prefix (default "/")
  #                   tags      stable tokens translated by the page locales
  #                   note      locale-key suffix under `note.`; the translated
  #                             text lives in the page locales, never here
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
  #   - the service overview page, which derives one card per enabled
  #     (service x host) row from this attribute set and from `homepage.hosts`
  #     below - ports, bind addresses and enablement stay single-sourced here.
  # ==========================================================================
  services = {
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

    # --- authenticated SOCKS5 + HTTP proxy (modules/nixos/base/custom/network/gost-proxy.nix)
    # Instance keys are `<destination-host>-<protocol>`: the host whose network
    # the entry point resolves on, plus the wire protocol the client speaks.
    # So `idols-ai-socks5` means the same destination-and-protocol on every
    # machine - directly on idols-ai, chained through it on wsl-work - and the
    # port column tells you which. Each row lists the instances that machine
    # declares; ports, not enablement, live here.
    gost-proxy = rec {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          ports = {
            idols-ai-socks5 = 1080; # direct SOCKS5 listener (curl/ssh/proxychains)
            idols-ai-http = 1081; # direct HTTP listener (browser facing)
          };
        };
        wsl-work = {
          enable = true;
          host = "0.0.0.0";
          ports = {
            wsl-work-socks5 = 1080; # direct SOCKS5 listener, same number as idols-ai today
            wsl-work-http = 1081; # direct HTTP listener, same number as idols-ai today
            idols-ai-socks5 = 31080; # wsl-work only: chains through idols-ai's proxy
            idols-ai-http = 31081; # ... its HTTP twin, same chain target
          };
        };
      };
      # What the chained `idols-ai-*` instances on wsl-work dial, keyed like
      # `ports` so `upstreams.idols-ai-socks5` is the upstream of the instance
      # of the same name. Derived from idols-ai's own port instead of restated,
      # so the two can never drift apart. The hop is SOCKS5 (chainProtocol's
      # default), so both chained instances share this one value - point it at
      # `hosts.idols-ai.ports.idols-ai-http` and set chainProtocol = "http" if
      # idols-ai's SOCKS5 listener is ever retired.
      upstreams.idols-ai-socks5 = "${endpoints.y9000p2025.easytier}:${toString hosts.idols-ai.ports.idols-ai-socks5}";
    };

    # --- the 11xx block: one slot per LLM-facing gateway, 1100 onwards ---
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
      catalog = {
        tags = [
          "llm"
          "gateway"
        ];
        note = "new-api";
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
      catalog = {
        # The API on 1101 is not a browser target; link the WebUI on 1102.
        portKey = "adminPort";
        tags = [
          "llm"
          "gateway"
          "ui"
        ];
        note = "opencode2api";
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
      catalog = {
        tags = [
          "llm"
          "gateway"
        ];
        note = "mimocode2api";
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
      catalog = {
        tags = [
          "llm"
          "gateway"
        ];
        note = "m365-copilot2api";
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
      catalog = {
        tags = [
          "llm"
          "gateway"
        ];
        note = "cliproxyapi";
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
      catalog = {
        tags = [
          "llm"
          "gateway"
          "ui"
        ];
        note = "omniroute";
      };
    };

    # --- Our Free Model standalone gateway (base/custom/ai/our-free-model-standalone) ---
    # Takes the 1107 slot like the other gateways but stays loopback-only: the
    # gateway hard-binds 127.0.0.1 (the upstream entry point rejects any other
    # address), so nothing tunnels it; the row documents the port it is told to
    # take and the machines that run it for the catalog page.
    our-free-model-standalone = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "127.0.0.1";
          port = 1107;
        };
        wsl-y9000p2025 = {
          enable = true;
          host = "127.0.0.1";
          port = 1107;
        };
        wsl-work = {
          enable = true;
          host = "127.0.0.1";
          port = 1107;
        };
      };
      catalog = {
        tags = [
          "llm"
          "gateway"
          "loopback"
        ];
        note = "our-free-model-standalone";
      };
    };

    # the API and the management panel share one port; `panelPort` in
    # modules/nixos/base/custom/ai/agent2api.nix splits them when a host wants
    # only the API reachable
    agent2api = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 1108;
        };
        wsl-work = {
          enable = true;
          host = "0.0.0.0";
          port = 1108;
        };
      };
      catalog = {
        tags = [
          "llm"
          "gateway"
          "ui"
        ];
        note = "agent2api";
      };
    };

    # WebMux browser terminal server (base/custom/ai/webmux). Not a gateway, but
    # it is the surface the CLI agents of this block are driven from, so it takes
    # the next free 11xx slot instead of opening a second range. The access token
    # in /var/lib/webmux/config.toml is its only authentication.
    webmux = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 1109;
        };
        wsl-y9000p2025 = {
          enable = true;
          host = "0.0.0.0";
          port = 1109;
        };
        wsl-work = {
          enable = true;
          host = "0.0.0.0";
          port = 1109;
        };
      };
      catalog = {
        tags = [
          "agent"
          "ui"
        ];
        note = "webmux";
      };
    };

    meoo2api = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 1110;
        };
        wsl-y9000p2025 = {
          enable = true;
          host = "0.0.0.0";
          port = 1110;
        };
        wsl-work = {
          enable = true;
          host = "0.0.0.0";
          port = 1110;
        };
      };
      catalog = {
        tags = [
          "llm"
          "gateway"
          "ui"
        ];
        note = "meoo2api";
      };
    };

    # workbuddy2api (base/custom/ai/workbuddy2api): WorkBuddy / Qoder / Trae /
    # MiniMax / Doubao / CodeArts gateway. The API and its management panel share
    # this port; the gateway API key is generated into
    # /var/lib/workbuddy2api/api-key on first start.
    workbuddy2api = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 1111;
        };
        wsl-y9000p2025 = {
          enable = true;
          host = "0.0.0.0";
          port = 1111;
        };
        wsl-work = {
          enable = true;
          host = "0.0.0.0";
          port = 1111;
        };
      };
      catalog = {
        tags = [
          "llm"
          "gateway"
          "ui"
        ];
        note = "workbuddy2api";
      };
    };

    open-webui = {
      hosts = {
        idols-ai = {
          enable = false;
          host = "0.0.0.0";
          port = 1120;
        };
        wsl-y9000p2025 = {
          enable = false;
          host = "0.0.0.0";
          port = 1120;
        };
        wsl-work = {
          enable = false;
          host = "0.0.0.0";
          port = 1120;
        };
      };
      catalog = {
        tags = [
          "llm"
          "ui"
        ];
        note = "open-webui";
      };
    };

    # ACB（AgentChatBridge）：dsh 的 3080 是主端口，其余是桥/驱动/opencode/
    # 中继的内部端口。驱动与会话由 acbl 组件管理，这里只作端口登记与展示
    # 数据；会话清单不再由 nix-config 生成。
    acb = {
      hosts = {
        idols-ai = rec {
          enable = true;
          host = "127.0.0.1";
          # console / opencode 对外监听地址：0.0.0.0 = ZeroTier / Tailscale /
          # EasyTier / LAN 都能访问（仍分别要求 token / Basic Auth）。
          # dsh web 保持 host=127.0.0.1：它的安全校验只接受 SSH 隧道。
          exposeHost = "0.0.0.0";
          ports = {
            dsh = 3080;
            endpoint = 7700;
            console = 3100;
            driver-dsh = 3101;
            driver-dev = 3102;
            driver-snowluma-test = 3103;
            driver-group2 = 3104;
            opencode = 4097;
            relay = 3131;
            snowluma = 53001;
          };
        };
      };
      catalog = {
        # Console on 3100; the loopback dsh endpoint is deliberately not listed.
        portKey = "ports.console";
        bindKey = "exposeHost";
        tags = [
          "agent"
          "ui"
        ];
        note = "acb";
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
      catalog = {
        tags = [
          "files"
          "ui"
        ];
        note = "alist";
      };
    };

    # AstrBot chatbot + WebUI (base/custom/ai/astrbot.nix). Keeps upstream's
    # default 6185 instead of a 11xx slot so the URL matches AstrBot's docs.
    astrbot = {
      hosts = {
        idols-ai = {
          enable = false;
          host = "0.0.0.0";
          port = 6185;
        };
      };
      catalog = {
        tags = [
          "chat"
          "ui"
        ];
        note = "astrbot";
      };
    };

    # --- the service overview page (base/custom/services/homepage) ---
    homepage = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 8090;
        };
        wsl-y9000p2025 = {
          enable = true;
          host = "0.0.0.0";
          port = 8090;
        };
        wsl-work = {
          enable = true;
          host = "0.0.0.0";
          port = 8090;
        };
      };
      catalog = {
        tags = [
          "dashboard"
          "infra"
        ];
        note = "homepage";
      };
    };

    # --- subscription manager, fronted by Caddy (base/custom/network/sub-store) ---
    # The one service whose bind address a module option consumes directly
    # (`modules.sub-store.host`, see the shape notes above); its enable is
    # wired from the row the same way. port / frontendPort document what
    # idols-ai deploys for the catalog - the module defaults apply, and dae
    # pins the backend on 127.0.0.1:24500.
    # Local Ollama inference API (modules.ollama reads this row; the cuda flag
    # picks pkgs.ollama-cuda on NVIDIA hosts)
    ollama = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 11434;
          cuda = true;
        };
        wsl-y9000p2025 = {
          enable = true;
          host = "0.0.0.0";
          port = 11434;
          cuda = false;
        };
      };
      catalog = {
        tags = [
          "ai"
        ];
        note = "ollama api";
      };
    };

    sub-store = {
      hosts = {
        idols-ai = {
          enable = true;
          host = "0.0.0.0";
          port = 24500;
          frontendPort = 24501;
        };
      };
      catalog = {
        # Link the authenticated web panel, not the JSON API on 24500.
        portKey = "frontendPort";
        tags = [
          "proxy"
          "ui"
          "auth"
        ];
        note = "sub-store";
      };
    };
  };

  # ==========================================================================
  # homepage.hosts - the machines whose enabled services the overview page
  # lists, keyed by the same host key `services.*.hosts` uses. Only host-level
  # facts that cannot be derived from `devices` live here:
  #   kind      "nixos" or "wsl"; the page uses it for the WSL localhost note
  #   device    key in `devices` above whose overlay addresses this machine
  #             owns; null when the host has no overlay registration (e.g. a
  #             WSL distro without its own overlay client)
  #   magicDns  optional Tailscale MagicDNS name for access links; null until
  #             the tailnet suffix is declared here
  # Overlay addresses come from `devices.<device>.addrs`; LAN addresses are
  # intentionally not read by the page, so a host without a `device` entry is
  # rendered as unreachable from other machines.
  # ==========================================================================
  homepage.hosts = {
    idols-ai = {
      kind = "nixos";
      device = "y9000p2025";
      magicDns = null;
    };
    wsl-work = {
      kind = "wsl";
      device = "work";
      magicDns = null;
    };
    wsl-y9000p2025 = {
      kind = "wsl";
      device = null;
      magicDns = null;
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
  # The homepage module on the forwarding host also reads this table to render
  # local forward links (`forwardPort`); remote ports still come from `services`.
  # ==========================================================================
  tunnels.work =
    let
      # One forwarding row: `base` selects work's own address range (3xxxx =
      # forwarded from the laptop, 4xxxx = from infiniti) and the remote port
      # expression is reused for both ends, so each port is written once.
      mk = base: remoteHost: name: remotePort: {
        inherit
          name
          remoteHost
          remotePort
          ;
        localPort = base + remotePort;
      };
      # Every entry targets the laptop (idols-ai), so fix host and base here.
      laptop = mk 30000 endpoints.y9000p2025.easytier;
      infiniti = mk 40000 endpoints.infiniti.easytier;
      # Registry lookup by host key; `field` is a dotted path into the
      # service row, e.g. `regAi "new-api" "port"` or `regAi "acb" "ports.console"`.
      reg =
        host: name: field:
        lib.getAttrFromPath (lib.splitString "." field) services.${name}.hosts.${host};
      # Every entry targets the laptop (idols-ai), so derive the pinned form.
      regAi = reg "idols-ai";
    in
    [
      # idols-ai / y9000p2025 (10.126.126.150) - 3xxxx range
      (laptop "new-api" (regAi "new-api" "port"))
      (laptop "opencode2api" (regAi "opencode2api" "port"))
      (laptop "opencode2api-management-center" (regAi "opencode2api" "adminPort"))
      (laptop "mimocode2api" (regAi "mimocode2api" "port"))
      (laptop "M365-Copilot2API" (regAi "m365-copilot2api" "port"))
      (laptop "meoo2api" (regAi "meoo2api" "port"))
      (laptop "workbuddy2api" (regAi "workbuddy2api" "port"))
      (laptop "Agent2API" (regAi "agent2api" "port"))
      # The laptop's browser terminal, reachable from this distro on its own
      # local port as well (31109 = base + 1109), like the gateways above.
      (laptop "webmux" (regAi "webmux" "port"))
      (laptop "cliproxyapimanagementcenter" (regAi "cliproxyapi" "port"))
      # kept for a future re-enable:
      # (laptop "omniroute" (regAi "omniroute" "port"))
      # (laptop "our-free-model-standalone" (regAi "our-free-model-standalone" "port"))
      (laptop "acb-console" (regAi "acb" "ports.console"))
      (laptop "acb-opencode" (regAi "acb" "ports.opencode"))
      (laptop "openwebui" (regAi "open-webui" "port"))
      # dsh needs the ssh forward to work at all (its security checks reject
      # plain TCP), so the tunnel must speak ssh - kept for a future re-enable:
      # (laptop "dsh" 3080)
      # rdp / opencode / the LAN proxy on the laptop are not driven by a NixOS
      # module, so they stay unregistered (registry scope) and carry literals.
      (laptop "rdp_rd" 3389)
      (laptop "rdp_rc" 3390)
      (laptop "ssh" (regAi "ssh" "port"))
      (laptop "opencode" 4096)
      # (laptop "y9000p2025-proxy" 7897)
      # apatch-infiniti (10.126.126.154) - 4xxxx range; adb, the device's SOCKS
      # proxy and the Termux sshd run outside this flake, so their ports are
      # literals until a NixOS module owns them.
      (infiniti "adb" 5555)
      (infiniti "infiniti-proxy" 2080)
      (infiniti "termux-ssh" 8022)
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
