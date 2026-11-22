# Downstream additions to home/linux/gui/base/desktop-tools.nix, kept in a
# separate file so the upstream module stays byte-identical (list options
# concatenate across module definitions).
{
  config,
  lib,
  mylib,
  pkgs,
  # flake input, bound so the commented winpodx line below stays valid when uncommented
  winpodx,
  ...
}:
{
  # WinBoat: run Windows in a Podman container on top of host KVM (the wrapper
  # already ships freerdp/docker-compose/podman-compose; podman and the kvm
  # module come from the NixOS desktop module + hardware config). The package
  # is x86_64-only, so the aarch64 desktop (shoukei) skips it - same pattern
  # as zoom-us in media.nix.
  home.packages =
    with pkgs;
    lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
      winboat
      # TODO: test which one is better, and if we choose winpodx, we need to
      # persist winpodx data (`.winboat` / `~/winboat`, see the per-host
      # preservation-downstream.nix).
      # winpodx.packages.${pkgs.system}.winpodx
    ];

  # Scripts
  xdg.configFile."scripts".source =
    mylib.mklinkRelativeToRoot config "home/linux/gui/base/desktop/conf/scripts";
}
