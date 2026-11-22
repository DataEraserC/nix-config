# Downstream additions to home/base/tui/container.nix, kept in a separate file
# so the upstream module stays byte-identical (list options concatenate across
# module definitions).
{
  pkgs,
  ...
}:
{
  # `kubernetes-helm`: WA-002-era note - the pinned nixpkgs-2505 input upstream
  # used for helm regressions is gone; helm comes from current nixpkgs now.
  home.packages =
    with pkgs;
    [
      docker-compose
    ]
    ++ (if pkgs.stdenv.hostPlatform.isLinux then [ distrobox ] else [ ]);
}
