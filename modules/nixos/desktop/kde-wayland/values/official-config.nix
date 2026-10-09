{ lib, ... }:
{
  # Enable Plasma
  services.desktopManager.plasma6.enable = true;

  # Default display manager for Plasma
  services.displayManager.sddm = {
    enable = true;

    # To use Wayland (Experimental for SDDM)
    wayland.enable = true;
  };

  # Optionally enable xserver
  services.xserver.enable = true;

  # seahorse defaults to off on the KDE profile — expressed as mkDefault so a
  # host can still opt in with a normal-priority definition; a bare `false`
  # would both conflict with security.nix's `true` and stay un-overridable.
  programs.seahorse.enable = lib.mkDefault false;
}
