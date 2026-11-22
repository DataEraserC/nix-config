{ pkgs, ... }:
{
  # docker/podman/lxd CLIs: talk to a docker context on another machine
  # (e.g. a WSL host) from the phone; the daemons themselves do not run here.
  home.packages = with pkgs; [
    docker
    podman
    # lxd was removed from nixpkgs (unmaintained upstream); its successor
    # incus has no termux packaging, and the daemons do not run on droid
    # anyway - these CLIs only talk to contexts on other machines.
  ];
}
