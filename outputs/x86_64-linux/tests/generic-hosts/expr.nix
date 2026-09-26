# Eval test for the overlay address registry in vars/networking.nix: the
# (devices × networks) matrix behind `networking.extraHosts`, `peers` and
# `easytier.instances` on idols-ai / wsl-work / wsl-y9000p2025.
{ lib, ... }:
let
  networking = import ../../../../vars/networking.nix { inherit lib; };
in
{
  # Full /etc/hosts payload: pins every rendered line, so growing the matrix
  # (new device, new network) can never silently drop or move old entries.
  genericHosts = networking.genericHosts;
  # Backward-compatible device → { network = ip } view used by the
  # auto-shutdown channel probes in hosts/idols-ai.
  peers = networking.peers;
  # Structured address (ip + prefixLength + iface) of this machine.
  selfDevice = networking.overlayDevices.y9000p2025;
  # Derived hostName → CIDR view consumed by modules/.../easytier.nix.
  easytierInstances = networking.easytier.instances;
}
