{
  config,
  pkgs,
  lib,
  disko,
  myvars,
  mysecrets,
  nur-DataEraserC,
  nixGL,
  inputs,
  ...
}@args:
#############################################################
#
#  Ai - my main computer, with NixOS + Intel CPU + RTX 5070 Laptop GPU (Lenovo
#  Legion y9000p2025; earlier this file served a y7000k2021 and an r9000p2025),
#  for gaming & daily use.
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
  # This machine's key in the port registry (myvars.networking.services.*.hosts):
  # the flake host name, which is not `hostName` (`ai` here).
  serviceHost = "idols-ai";

in
rec {
  imports = [
    disko.nixosModules.default
    # disks
    ./disko-fs.nix

    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./hardware-intel.nix
    ./hardware-nvidia.nix

    ./preservation.nix
    ./preservation-downstream.nix
    ./downstream.nix # downstream module wiring (purely additive)
    ../service-user-ids.nix
    ./secureboot.nix
    ./sunshine.nix

    ./restic.nix

    # others
    ./ai
    ./proxmox.nix
    # ./tpm_luks.nix
  ];

  # CyIME's IBus component has to be merged into the directory the ibus-daemon
  # wrapper pins via IBUS_COMPONENT_PATH, otherwise the engine never shows up
  # in `ibus list-engine`. Commented out together with the cyime switch in
  # home/hosts/linux/idols-ai.nix so no component is left on fcitx5.
  # modules.cyime-ibus.enable = lib.mkIf config.modules.desktop.gnome-wayland.enable true;

  # ACB 的 dsh preset 不再静态声明：由 dsh-presets 组件在 dsh 就绪后安装动态 bundle。

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

  # WARP tunnel + its root CA cert, replaces the connection between this
  # device and the Internet. Download:
  # https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/install-cloudflare-cert/
  features.cloudflare-warp = {
    enable = true;
    certificate = "${mysecrets}/public/Cloudflare_CA.pem";
  };

  # firmware update tool
  services.fwupd.enable = true;

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
