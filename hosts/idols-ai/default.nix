{
  config,
  pkgs,
  lib,
  disko,
  myvars,
  mysecrets,
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
  hostName = "ai"; # Define your hostname.

  macAddress = "02:d7:de:84:1e:e9";
  inherit (myvars.networking) mainGateway mainGateway6 nameservers;
  inherit (myvars.networking.hostsAddr.${hostName}) iface ipv4 ipv6;
  ipv4WithMask = "${ipv4}/24";
  ipv6WithMask = "${ipv6}/64";

  # One ping-based condition per overlay endpoint; addresses come from named
  # vars only, never hardcoded.
  pingCondition = name: ip: {
    inherit name;
    command = pkgs.writeShellScript "auto-shutdown-${lib.replaceStrings [ " " ] [ "-" ] name}" ''
      exec ${pkgs.iputils}/bin/ping -c 1 -W 2 ${ip}
    '';
  };

  # This machine's key in the port registry (myvars.networking.services.*.hosts):
  # the flake host name, which is not `hostName` (`ai` here).
  serviceHost = "idols-ai";
  # One service's row on this machine - `svc "new-api"` is
  # myvars.networking.services.new-api.hosts.idols-ai - so the key above is the
  # only place it is spelled out.
  svc = service: myvars.networking.services.${service}.hosts.${serviceHost};

in
rec {
  imports = [
    disko.nixosModules.default
    # disks
    ./disko-fs.nix
    # ./disko-fs-data.nix
    # ./netdev-mount.nix

    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./hardware-intel.nix
    ./hardware-nvidia.nix

    ./preservation.nix
    ./preservation-downstream.nix
    ../service-user-ids.nix
    ./secureboot.nix
    ./sunshine.nix

    ./restic.nix

    # others
    ./ai
    ./proxmox.nix
    # ./tpm_luks.nix
  ];

  # dae transparent proxy - the shared module lives in
  # modules/nixos/base/custom/network/dae.nix and is only enabled on this host for now.
  # Its main config is the host-local ./config.dae, the subscription comes from agenix.
  modules.dae = {
    enable = true;
    # dae fetches subscriptions only at startup/reload, so reload once an hour to
    # pick up Sub-Store's refreshed node lists; the oneshot skips while dae is
    # stopped (e. while it is kept off to avoid a rebuild failure).
    autoReload = {
      enable = true;
      interval = "60min";
    };
    installFiles = [
      {
        source = ./config.dae;
        target = "/etc/dae/config.dae";
      }
      {
        source = config.age.secrets."dae-subscription.dae".path;
        target = "/etc/dae/config.d/subscription.dae";
      }
    ];
  };

  # Static service overview page (modules/nixos/base/custom/services/homepage).
  # Port, bind address and enable state come from services.homepage.hosts.idols-ai;
  # the page lists every registry service that carries a catalog block.
  modules.homepage = {
    enable = (svc "homepage").enable;
    host = (svc "homepage").host;
    port = (svc "homepage").port;
    hostKey = serviceHost;
  };

  # Sub-Store converts Clash-format subscriptions into base64 v2ray URI lists
  # that dae can fetch (dae has no Clash-YAML parser). Caddy fronts API 24500 and
  # web panel 24501 with Basic Auth (agenix secret sub-store.caddy), the panel
  # calling its API on the same 24501 origin (no cross-port CORS); Sub-Store
  # itself sits on loopback internal ports behind it. Passwordless on purpose:
  # loopback (dae, local panel) and every GET /download/* subscription link.
  # The host firewall still only trusts tailscale/zerotier/easytier, so
  # openFirewall stays off - flip it on later to reach the ports from the campus
  # LAN (asserted to require auth.enable).
  # See modules/nixos/base/custom/network/sub-store/default.nix.
  modules.sub-store = {
    enable = (svc "sub-store").enable;
    host = (svc "sub-store").host;
    auth = {
      enable = true;
      file = config.age.secrets."sub-store.caddy".path;
    };
    # Re-fetch every registered upstream hourly so /download/<name>/v2ray always
    # serves fresh nodes plus a #cacheKey disk fallback for dae's cold start.
    autoRefresh = {
      enable = true;
      interval = "60min";
      subs = [
        "GarbageDump1"
        "iKuuu1"
        "iKuuu2"
        "Mojie1"
        "Xxmad1"
      ];
    };
  };

  # ACB：开关、绑定地址、端口和会话列表全部读 services.acb 注册表。
  modules.acb = {
    enable = (svc "acb").enable;
    host = (svc "acb").host;
    exposeHost = (svc "acb").exposeHost;
    dshPort = (svc "acb").ports.dsh;
    endpointPort = (svc "acb").ports.endpoint;
    consolePort = (svc "acb").ports.console;
    opencodePort = (svc "acb").ports.opencode;
    relayPort = (svc "acb").ports.relay;
    snowlumaPort = (svc "acb").ports.snowluma;
    sessions = (svc "acb").sessions;
    secretsFile = config.age.secrets."acb.env".path;
  };

  # ACB 的 dsh preset 列表：每条生成一个 agent preset + 自己的 MCP client。
  modules.dsh.acbSessions = (svc "acb").sessions;

  # Zram consumes physical memory for compression, which can cause a deadlock and system hang if the model size approaches the physical memory limit.
  # Disable the whole module (zram device + its swappiness=180 sysctl tunings); this host uses a disk swapfile instead.
  modules.zram.enable = false;

  # zswap: compressed writeback cache in front of the disk swapfile.
  # Keeps swapped cold anon pages compressed in RAM instead of the SSD, which frees more
  # page cache for the ~78GB mmap'd LLM weights (mmap file pages never go through zswap).
  # Safe here: disk swapfile remains the real backing store, no zram deadlock structure.
  # - zstd: CPU is not the bottleneck here (llama.cpp peaks ~30% util); its ~2.5x ratio
  #   keeps ~5G more anon bytes in the capped pool than lz4, and ~5us decompress is noise
  #   vs the ~100us SSD fault it avoids.
  # - 10% pool (~13G on 128G): the module default 25% (~32G) would compete with the weight
  #   cache.
  boot.zswap = {
    enable = true;
    compressor = "zstd";
    maxPoolPercent = 10;
  };

  services.sunshine.enable = true;
  services.tuned.ppdSettings.main.default = lib.mkForce "performance";

  modules.btrbk.enable = true;

  # Confine Nix builds to a cgroup budget so a runaway build does not trigger
  # the kernel global OOM killer and take an Electron renderer with it. Values
  # and rationale live in vars/nix-build-guard.nix.
  modules.nix-build-guard.enable = true;

  # Permit the desktop user to access Intel accelerator devices for local ASR.
  users.users.${myvars.username}.extraGroups = [ "render" ];

  # systemd-journal - cap disk usage
  # https://www.freedesktop.org/software/systemd/man/latest/journald.conf.html
  services.journald.settings.Journal = {
    SystemMaxUse = "10G";
    RuntimeMaxUse = "256M";
  };

  # Monitor SSD/NVMe SMART attributes so a drive going bad is visible before it
  # fails, and so there is data behind the relaxed NVMe power-management
  # settings in hardware-configuration.nix. smartd autodetects devices and
  # reports to the journal (mail notifications stay off without an MTA).
  services.smartd.enable = true;

  # QEMU/KVM(HostCpuOnly) for local VMs.
  environment.systemPackages = [
    pkgs.qemu_kvm
  ]
  # NTFS3G for windows disk
  ++ [ pkgs.ntfs3g ];

  # Re-evaluate after the Insta360 Link firmware or the kernel's uvcvideo changes.
  powerManagement.resumeCommands = ''
    # Insta360 Link may stay enumerated with a stalled UVC endpoint after S3 resume.
    ${pkgs.coreutils}/bin/sleep 1
    ${pkgs.usbutils}/bin/usbreset 2e1a:4c01 || true
  '';

  # NTFS mounts use ntfs-3g (userspace FUSE) instead of the kernel ntfs3 driver.
  # The blacklist stops udisks/GNOME automounts and `mount -t ntfs` from picking
  # ntfs3, so they fall back to the mount.ntfs-3g helper; static mounts use
  # fsType "ntfs3g" (see hardware-configuration.nix). Needed for reliable
  # read/write on removable media and dirty/hibernated Windows volumes.
  boot.blacklistedKernelModules = [
    "ntfs3"
  ];

  # ntfy notifications on network up/down events(NM dispatcher, shared script)
  modules.network-event-notify = {
    enable = true;
    inherit hostName;
  };

  # periodic host liveness heartbeat via ntfy
  modules.host-heartbeat = {
    enable = true;
    interval = "30min";
    inherit hostName;
    username = myvars.username;
  };

  # ntfy warnings when the AC power supply is unplugged/restored(udev-driven)
  modules.power-event-notify = {
    enable = true;
    inherit hostName;
  };

  # one-shot cpolar tunnel status report after boot
  modules.cpolar-status = {
    enable = true;
    inherit hostName;
    username = myvars.username;
  };

  # Oray PgyVisitor SDN client
  modules.pgy.enable = true;

  # EasyTier decentralized P2P VPN
  modules.easytier.enable = true;

  # Authenticated SOCKS5 + HTTP proxy (shared
  # modules/nixos/base/custom/network/gost-proxy.nix).
  # Two listeners on every interface, but the firewall only trusts the overlay
  # interfaces (easytier/tailscale/zerotier) and openFirewall stays off, so the
  # campus LAN cannot connect - proxy credentials are clear text there.
  # Credentials come from the agenix secret gost-proxy.auth.
  #   - idols-ai-socks5 (1080): for curl / ssh / proxychains. This is also the
  #     chained upstream of wsl-work's idols-ai-socks5 (31080) and
  #     idols-ai-http (31081) entry points, whose clients reach this host's
  #     loopback (dsh GUI on 127.0.0.1:3080) through it.
  #   - idols-ai-http (1081): the same proxy for browsers, which cannot send
  #     SOCKS5 credentials (Chromium not at all, Firefox only via about:config).
  # They are independent instances, so either one can be retired later with
  # `instances.<name>.enable = false` without touching the other.
  modules.gost-proxy = {
    enable = (svc "gost-proxy").enable;
    instances = {
      idols-ai-socks5.port = (svc "gost-proxy").ports.idols-ai-socks5;
      idols-ai-http = {
        port = (svc "gost-proxy").ports.idols-ai-http;
        protocol = "http";
      };
    };
  };

  # CLIProxyAPI proxy with an offline management panel, bound to 0.0.0.0:1105.
  modules.cliproxyapi.enable = (svc "cliproxyapi").enable;
  modules.cliproxyapi.port = (svc "cliproxyapi").port;

  # M365 Copilot2API gateway, bound to 0.0.0.0:1104.
  modules.m365-copilot2api.enable = (svc "m365-copilot2api").enable;
  modules.m365-copilot2api.port = (svc "m365-copilot2api").port;

  # Agent2API gateway, bound to 0.0.0.0:1108 (API and management panel).
  modules.agent2api.enable = (svc "agent2api").enable;
  modules.agent2api.port = (svc "agent2api").port;

  # opencode2api gateway, bound to 0.0.0.0:1101 (API) and 0.0.0.0:1102 (WebUI).
  modules.opencode2api.enable = (svc "opencode2api").enable;
  modules.opencode2api.port = (svc "opencode2api").port;
  modules.opencode2api.webUiPort = (svc "opencode2api").adminPort;

  # mimocode2api gateway, bound to 0.0.0.0:1103 (VPN interfaces only).
  modules.mimocode2api.enable = (svc "mimocode2api").enable;
  modules.mimocode2api.port = (svc "mimocode2api").port;

  # OmniRoute unified LLM gateway, bound to 0.0.0.0:1106.
  modules.omniroute.enable = (svc "omniroute").enable;
  modules.omniroute.port = (svc "omniroute").port;

  # new-api LLM gateway, port 1100 (upstream listens on all interfaces).
  modules.new-api.enable = (svc "new-api").enable;
  modules.new-api.port = (svc "new-api").port;

  # Our Free Model standalone gateway, 127.0.0.1:1107 (loopback only).
  modules.our-free-model-standalone.enable = (svc "our-free-model-standalone").enable;
  modules.our-free-model-standalone.port = (svc "our-free-model-standalone").port;

  # Open WebUI chat frontend, 0.0.0.0:1120 (shared modules.open-webui) - disabled.
  modules.open-webui.enable = (svc "open-webui").enable;
  modules.open-webui.port = (svc "open-webui").port;

  # alist (openlist) file listing, bound to 0.0.0.0:5244.
  modules.alist.enable = (svc "alist").enable;
  modules.alist.port = (svc "alist").port;
  modules.alist.s3Port = (svc "alist").s3Port;

  # AstrBot chatbot + WebUI, bound to 0.0.0.0:6185 (shared modules.astrbot).
  # Native deployment: the pinned upstream source runs on Nix's python312 with a
  # uv-provisioned venv under /var/lib/astrbot (see the module header); the
  # first start downloads the wheel set, so give it a few minutes.
  modules.astrbot.enable = (svc "astrbot").enable;
  modules.astrbot.port = (svc "astrbot").port;

  # Clash Verge Rev GUI client (shared modules/nixos/base/custom/network/clash-verge.nix,
  # nixpkgs programs.clash-verge with the package from nixpkgs-master). Service
  # mode runs the mihomo core as a root systemd unit; autoStart and TUN stay off
  # (dae owns transparent proxying here, so no second TUN stack).
  modules.clash-verge.enable = true;

  # Route CLI traffic through the local / LAN SOCKS proxies.
  modules.proxychains.enable = true;

  # Agent tools and AI IDEs from nur-DataEraserC: CodeBuddy, WorkBuddy, WorkBuddy
  # International, LobsterAI, Trae CN, Trae International, ZCode CN and ZCode
  # International are on, CodeArts stays parked. Their state (~/.codebuddy,
  # ~/.codeartsdoer, ~/.workbuddy, ~/.workbuddy-ai,
  # ~/.local/share/CodeBuddyExtension, ~/.config/LobsterAI, ~/lobsterai,
  # ~/.trae-cn, ~/.trae, ~/.config/Trae CN, ~/.config/Trae, ~/.zcode,
  # ~/.config/ZCode) is persisted unconditionally in preservation-downstream.nix,
  # so re-enabling one keeps the login and history already on disk.
  # See modules/nixos/base/custom/ai/{codebuddy,codearts,workbuddy,workbuddy-ai,lobsterai,trae-cn,trae-intl,zcode-cn,zcode-intl}.nix.
  modules.codebuddy.enable = true;
  # modules.codearts.enable = true;
  modules.workbuddy.enable = true;
  modules.workbuddy-ai.enable = true;
  modules.lobsterai.enable = true;
  modules.trae-cn.enable = true;
  modules.trae-intl.enable = true;
  modules.zcode-cn.enable = true;
  modules.zcode-intl.enable = true;
  # `multi-instance <app> <account>`: the same apps under bubblewrap with one
  # state directory per account; see modules/nixos/base/custom/ai/agent-accounts.nix.
  modules.agent-accounts.enable = true;
  modules.agent-accounts.desktopAccounts = {
    workbuddy = 2;
    workbuddy-ai = 6;
    lobsterai = 2;
    trae-cn = 2;
    trae = 6;
    zcode-cn = 2;
    zcode = 6;
  };

  # WARP tunnel + its root CA cert, replaces the connection between this
  # device and the Internet. Download:
  # https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/install-cloudflare-cert/
  features.cloudflare-warp = {
    enable = true;
    certificate = "${mysecrets}/public/Cloudflare_CA.pem";
  };

  # firmware update tool
  services.fwupd.enable = true;

  # Power off when NO channel to reach this device remains for 30min. The
  # offline-assessment is "do I still have any channel to connect in through",
  # so every overlay channel gets its own probe and `mode = "any"` keeps the
  # machine on while even one channel answers. All endpoints come from
  # myvars.networking.peers (easytier/zerotier/tailscale).
  # For temporary live tweaks without a rebuild use
  # `sudo auto-shutdown {disable|enable|grace|reset}`(changes reset on reboot).
  # See modules/nixos/base/custom/system/auto-shutdown/default.nix.
  modules.auto-shutdown = {
    enable = true;
    mode = "any";
    conditions = [
      # easytier: the primary and most stable channel -> probe both peers
      (pingCondition "easytier infiniti" myvars.networking.peers.infiniti.easytier)
      (pingCondition "easytier wsl-work" myvars.networking.peers.work.easytier)
      # tailscale: the android peer answers `tailscale ping` but not ICMP,
      # so probe at the tailscale layer(exit 0 on pong, non-zero on timeout)
      {
        name = "tailscale infiniti";
        command = pkgs.writeShellScript "auto-shutdown-tailscale-infiniti" ''
          exec ${pkgs.tailscale}/bin/tailscale ping -c 1 ${myvars.networking.peers.infiniti.tailscale}
        '';
      }
      # zerotier: ICMP probe of the android endpoint(passes while that device
      # is online on the zerotier network; zerotier-cli cannot map IP->node)
      (pingCondition "zerotier infiniti" myvars.networking.peers.infiniti.zerotier)
    ];
    gracePeriod = "30min";
    checkInterval = "10min";
    verbose = true;
  };

  networking = {
    inherit hostName;
    # hostName = "DESKTOP-GM6XG0X";

    # we use networkd instead
    # networkmanager.enable = false; # provides nmcli/nmtui for wifi adjustment
    # useDHCP = false;

    # desktop need its cli for status bar
    networkmanager.enable = true;
    networkmanager.wifi.macAddress = macAddress;
    networkmanager.ethernet.macAddress = macAddress;
    extraHosts = myvars.networking.genericHosts;
  };

  # conflict with feature: containerd-snapshotter
  # virtualisation.docker.storageDriver = "btrfs";

  # Point this link's DNS at mihomo while it runs, and revert it when it stops.
  #
  # Why a lifecycle hook: mihomo's sing-tun stack would call resolvectl itself,
  # but nixpkgs' DynamicUser+hardened unit closes the D-Bus socket and SetLinkDNS
  # needs privileged authorization; without the takeover resolved's upstream
  # queries bypass dns-hijack and leave via the NIC. The '+' prefix escapes that
  # sandbox -- a failed ExecStartPost would kill a healthy service -- and
  # ExecStopPost also runs on crashes, so a dead mihomo leaves the network usable.
  #
  # Why the probe: the core opens :1053 only after parsing the rules, and rule
  # parsing is where missing geodata gets fetched. Flipping at fork time pointed
  # that fetch at a port nobody was listening on -- SERVFAIL, a fatal config
  # error, a unit that could never start.
  systemd.services.mihomo.serviceConfig = {
    ExecStartPost = lib.mkDefault "+${pkgs.writeShellScript "mihomo-dns-takeover" ''
      probe() { (exec 3<>/dev/tcp/127.0.0.1/1053) 2>/dev/null; }
      up=0
      for ((i = 0; i < 100; i++)); do
        if probe; then up=1; break; fi
        sleep 0.1
      done
      if [ "$up" = 0 ]; then
        echo "mihomo never opened 127.0.0.1:1053; leaving ${iface} on its own DNS" >&2
        exit 0
      fi
      exec ${pkgs.systemd}/bin/resolvectl dns ${iface} 127.0.0.1:1053
    ''}";
    ExecStopPost = lib.mkDefault "+${pkgs.systemd}/bin/resolvectl revert ${iface}";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.11"; # Did you read the comment?
  features.bigdata_hadoop = {
    enable = false;
    package = pkgs.hadoop_3_3;
    impermanence.enable = true;
  };
}
