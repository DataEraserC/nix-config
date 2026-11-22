# Downstream idols-ai runs NetworkManager (upstream runs systemd-networkd with
# a "10-lan" network), so this test asserts the downstream networking facts:
# NM enabled with the machine's MAC pinned on both wifi and ethernet, the
# Noctalia net widgets present in the deployed config, and the mihomo DNS
# takeover referencing the interface from myvars.
{
  lib,
  mylib,
  myvars,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  hm = cfg.home-manager.users.${myvars.username};
  inherit (myvars.networking.hostsAddr.ai) iface;
  # The deployed config.toml is an out-of-store symlink to this repo file;
  # read the repo copy (an absolute-path readFile is forbidden in pure eval).
  noctalia = builtins.readFile (
    mylib.relativeToRoot "home/linux/gui/base/noctalia/config/config.toml"
  );

  nm = cfg.networking.networkmanager;
  macAddress = "02:d7:de:84:1e:e9"; # hosts/idols-ai/default.nix `macAddress`
in
{
  networkManagerEnabled = nm.enable;

  # Both wifi and ethernet pin the same machine MAC, so the DHCP lease and any
  # router-side rules stay stable across reboots.
  macAddressPinned = nm.wifi.macAddress == macAddress && nm.ethernet.macAddress == macAddress;

  # The bar carries both directions of the net-speed widget (sysmon type).
  noctaliaNetWidgetsPresent =
    lib.hasInfix "[widget.net_rx]" noctalia && lib.hasInfix "[widget.net_tx]" noctalia;

  # The mihomo DNS-takeover hook releases ${iface} from resolved when mihomo
  # dies; a drift of the interface name would leave the NIC on a dead DNS.
  # ExecStartPost is the store path of the takeover script (its content is not
  # readable as an option), so assert the hook is wired to the mihomo unit.
  mihomoDnsTakeoverWired = lib.hasInfix "mihomo-dns-takeover" cfg.systemd.services.mihomo.serviceConfig.ExecStartPost;
}
