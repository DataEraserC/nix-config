{ pkgs, ... }:
{
  # docker/podman/lxd CLIs: talk to a docker context on another machine
  # (e.g. a WSL host) from the phone; the daemons themselves do not run here.
  home.packages = with pkgs; [
    docker
    podman
    lxd
  ];
}
