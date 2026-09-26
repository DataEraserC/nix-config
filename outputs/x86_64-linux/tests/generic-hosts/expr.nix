# Eval test for the overlay `genericHosts` generator in vars/networking.nix:
# the (devices × networks) cross product that feeds `networking.extraHosts`
# on idols-ai / wsl-work / wsl-y9000p2025.
{ lib, ... }:
let
  networking = import ../../../../vars/networking.nix { inherit lib; };
in
{
  # Full /etc/hosts payload: pins every rendered line, so growing the matrix
  # (new device, new network) can never silently drop or move old entries.
  genericHosts = networking.genericHosts;
  # Backward-compatible device → { network = IP } view used by the
  # auto-shutdown channel probes in hosts/idols-ai.
  peers = networking.peers;
  # easytier instances expose bare IPs next to their CIDR form.
  easytierIps = networking.easytier.ips;
}
