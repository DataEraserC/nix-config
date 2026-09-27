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
    ./dae.nix
  ];

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

  # CLIProxyAPI proxy with an offline management panel, bound to 0.0.0.0:8317.
  modules.cliproxyapi.enable = false;

  # M365 Copilot2API gateway, bound to 0.0.0.0:4141.
  modules.m365-copilot2api.enable = true;

  # opencode2api gateway, bound to 0.0.0.0:4142 (API) and 0.0.0.0:4143 (WebUI).
  modules.opencode2api.enable = true;

  # mimocode2api gateway, bound to 0.0.0.0:4144 (VPN interfaces only).
  modules.mimocode2api.enable = true;

  # new-api LLM gateway, bound to 0.0.0.0:3000.
  modules.new-api.enable = true;

  # alist (openlist) file listing, bound to 0.0.0.0:5244.
  modules.alist.enable = true;

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
  # See modules/nixos/base/custom/auto-shutdown.nix.
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
