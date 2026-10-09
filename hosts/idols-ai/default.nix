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
    ./secureboot.nix
    ./sunshine.nix

    # others
    ./ai
    ./proxmox.nix
    # ./tpm_luks.nix
  ];

  # dae transparent proxy - the shared module lives in
  # modules/nixos/base/custom/dae.nix and is only enabled on this host for now.
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

  # Sub-Store converts Clash-format subscriptions into base64 v2ray URI lists
  # that dae can fetch (dae has no Clash-YAML parser). Caddy fronts API 24500 and
  # web panel 24501 with Basic Auth (agenix secret sub-store.caddy), the panel
  # calling its API on the same 24501 origin (no cross-port CORS); Sub-Store
  # itself sits on loopback internal ports behind it. Passwordless on purpose:
  # loopback (dae, local panel) and every GET /download/* subscription link.
  # The host firewall still only trusts tailscale/zerotier/easytier, so
  # openFirewall stays off - flip it on later to reach the ports from the campus
  # LAN (asserted to require auth.enable).
  # See modules/nixos/base/custom/sub-store/default.nix.
  modules.sub-store = {
    enable = myvars.networking.services.sub-store.hosts.idols-ai.enable;
    host = myvars.networking.services.sub-store.hosts.idols-ai.host;
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
  # - 10% pool (~9G): the module default 25% (~23G) would compete with the weight cache.
  boot.zswap = {
    enable = true;
    compressor = "zstd";
    maxPoolPercent = 10;
  };

  services.sunshine.enable = true;
  services.tuned.ppdSettings.main.default = lib.mkForce "performance";

  # NTFS mounts use ntfs-3g (userspace FUSE) instead of the kernel ntfs3 driver.
  # The blacklist stops udisks/GNOME automounts and `mount -t ntfs` from picking
  # ntfs3, so they fall back to the mount.ntfs-3g helper; static mounts use
  # fsType "ntfs3g" (see hardware-configuration.nix). Needed for reliable
  # read/write on removable media and dirty/hibernated Windows volumes.
  boot.blacklistedKernelModules = [
    "ntfs3"
  ];
  environment.systemPackages = [
    pkgs.ntfs3g
    # antigravity-cli (`agy`): installed for dsh/modlens, NOT as a standalone
    # agent CLI like opencode/kimi-code. modlens's `antigravity-cli` vision
    # provider spawns `agy` as a subprocess from PATH, so it must be on the
    # system profile. State (OAuth login, config, logs) lives in ~/.gemini,
    # which preservation.nix keeps across boots.
    pkgs.antigravity-cli
  ];

  # powerManagement.resumeCommands = ''
  #   # Insta360 Link may stay enumerated with a stalled UVC endpoint after S3 resume.
  #   ${pkgs.coreutils}/bin/sleep 1
  #   ${pkgs.usbutils}/bin/usbreset 2e1a:4c01 || true
  # '';

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

  # Authenticated SOCKS5 proxy (shared modules/nixos/base/custom/gost-proxy.nix).
  # Listens on 1080 for every interface, but the firewall only trusts the
  # overlay interfaces (easytier/tailscale/zerotier) and openFirewall stays off,
  # so the campus LAN cannot connect - SOCKS5 credentials are clear text there.
  # Credentials come from the agenix secret gost-proxy.auth. This instance is
  # also the chained upstream of wsl-work:31080, whose clients reach this
  # host's loopback (dsh GUI on 127.0.0.1:9900) through it.
  modules.gost-proxy = {
    enable = myvars.networking.services.gost-proxy.hosts.idols-ai.enable;
    instances.proxy.port = myvars.networking.services.gost-proxy.hosts.idols-ai.ports.proxy;
  };

  # CLIProxyAPI proxy with an offline management panel, bound to 0.0.0.0:1105.
  modules.cliproxyapi.enable = myvars.networking.services.cliproxyapi.hosts.idols-ai.enable;
  modules.cliproxyapi.port = myvars.networking.services.cliproxyapi.hosts.idols-ai.port;

  # M365 Copilot2API gateway, bound to 0.0.0.0:1104.
  modules.m365-copilot2api.enable = myvars.networking.services.m365-copilot2api.hosts.idols-ai.enable;
  modules.m365-copilot2api.port = myvars.networking.services.m365-copilot2api.hosts.idols-ai.port;

  # opencode2api gateway, bound to 0.0.0.0:1101 (API) and 0.0.0.0:1102 (WebUI).
  modules.opencode2api.enable = myvars.networking.services.opencode2api.hosts.idols-ai.enable;
  modules.opencode2api.port = myvars.networking.services.opencode2api.hosts.idols-ai.port;
  modules.opencode2api.webUiPort = myvars.networking.services.opencode2api.hosts.idols-ai.adminPort;

  # mimocode2api gateway, bound to 0.0.0.0:1103 (VPN interfaces only).
  modules.mimocode2api.enable = myvars.networking.services.mimocode2api.hosts.idols-ai.enable;
  modules.mimocode2api.port = myvars.networking.services.mimocode2api.hosts.idols-ai.port;

  # OmniRoute unified LLM gateway, bound to 0.0.0.0:1106.
  modules.omniroute.enable = myvars.networking.services.omniroute.hosts.idols-ai.enable;
  modules.omniroute.port = myvars.networking.services.omniroute.hosts.idols-ai.port;

  # new-api LLM gateway, port 1100 (upstream listens on all interfaces).
  modules.new-api.enable = myvars.networking.services.new-api.hosts.idols-ai.enable;
  modules.new-api.port = myvars.networking.services.new-api.hosts.idols-ai.port;

  # Open WebUI chat frontend, 0.0.0.0:1107 (shared modules.open-webui) - disabled.
  modules.open-webui.enable = myvars.networking.services.open-webui.hosts.idols-ai.enable;
  modules.open-webui.port = myvars.networking.services.open-webui.hosts.idols-ai.port;

  # alist (openlist) file listing, bound to 0.0.0.0:5244.
  modules.alist.enable = myvars.networking.services.alist.hosts.idols-ai.enable;
  modules.alist.port = myvars.networking.services.alist.hosts.idols-ai.port;
  modules.alist.s3Port = myvars.networking.services.alist.hosts.idols-ai.s3Port;

  # Route CLI traffic through the local / LAN SOCKS proxies.
  modules.proxychains.enable = true;

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
  # See modules/nixos/base/custom/auto-shutdown/default.nix.
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
