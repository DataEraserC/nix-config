{
  genericHosts = ''
    155.248.179.129 oracle_ubuntu_1.mayuri.org

    10.147.20.154 infiniti_android_cli_zerotier.mayuri.org
    100.95.92.154 infiniti_android_cli_tailscale.mayuri.org
    10.126.126.154 infiniti_android_cli_easytier.mayuri.org

    10.147.20.151 mondrian_android_cli_zerotier.mayuri.org
    100.95.92.151 mondrian_android_cli_tailscale.mayuri.org

    10.147.20.153 pstar_android_cli_zerotier.mayuri.org
    100.95.92.153 pstar_android_cli_tailscale.mayuri.org

    10.126.126.170 work_wsl_easytier.mayuri.org

    10.147.20.150 y9000p2025_nixos_zerotier.mayuri.org
    100.95.92.150 y9000p2025_nixos_tailscale.mayuri.org
    10.126.126.150 y9000p2025_nixos_easytier.mayuri.org
  '';
  peers = {
    infiniti = {
      zerotier = "10.147.20.154";
      tailscale = "100.95.92.154";
      easytier = "10.126.126.154";
    };
    mondrian = {
      zerotier = "10.147.20.151";
      tailscale = "100.95.92.151";
    };
    pstar = {
      zerotier = "10.147.20.153";
      tailscale = "100.95.92.153";
    };
    work = {
      easytier = "10.126.126.170";
    };
  };
  selfDevice = {
    class = "nixos";
    hostName = "ai";
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
  easytierInstances = {
    ai = "10.126.126.150/24";
    work = "10.126.126.170/24";
  };
}
