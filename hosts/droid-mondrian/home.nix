{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Read the changelog before changing this value.
  # This device was set up on 24.05; ../base/home.nix (shared by every home)
  # now declares 26.05, so keep the historical value for droid-mondrian with
  # mkForce instead of silently migrating it.
  home.stateVersion = lib.mkForce "24.05";

  # insert home-manager config
}
