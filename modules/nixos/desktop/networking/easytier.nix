# =============================================================
#
# EasyTier - a decentralized P2P VPN
#
# It's open source and free for personal use.
# EasyTier is a simple, decentralized, and cross-platform P2P VPN,
# supporting Linux, macOS, Windows, Android, iOS, etc.
#
# The `services.easytier` NixOS options are searchable via
#   `nixos options services.easytier`
#
# How to use:
#   Network credentials (ET_NETWORK_NAME, ET_NETWORK_SECRET) are
#   stored as agenix secrets and injected via environmentFiles.
#   Override other settings per host in your own host config, e.g.:
#     services.easytier.instances.main.settings = {
#       peers = [ "tcp://myserver.example.com:11010" ];
#     };
#
# Status Data:
#   `journalctl -u easytier-<instance>` shows easytier's logs
#   easytier store its data in /var/lib/easytier
#
# References:
# https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/easytier.nix
# https://github.com/EasyTier/EasyTier
#
# =============================================================
{
  config,
  pkgs,
  myvars,
  ...
}:
let
  hostName = config.networking.hostName;
  et = myvars.networking.easytier;
in
{
  # make the easytier command usable to users
  environment.systemPackages = [ pkgs.easytier ];

  # enable the easytier service
  services.easytier = {
    enable = true;
    instances.main = {
      environmentFiles = [
        config.age.secrets."easytier-env".path
      ];
      settings = {
        hostname = hostName;
        network_name = null;
        network_secret = null;
        ipv4 = et.instances.${hostName};
        listeners = [
          "tcp://0.0.0.0:11010"
          "udp://0.0.0.0:11010"
        ];
      };
      # Give the virtual NIC a recognizable name instead of the default tun0.
      extraArgs = [
        "--dev-name"
        "easytier0"
      ];
    };
  };
}
