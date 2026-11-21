{ ... }:
{
  # Enable Plasma
  services.desktopManager.plasma6.enable = true;

  # Default display manager for Plasma
  services.displayManager.sddm = {
    enable = true;

    # To use Wayland (Experimental for SDDM)
    wayland.enable = true;
  };

  # seahorse (the GNOME Keyring GUI) stays off in the KDE profile: this plain
  # `false` is the only definition here - security.nix's `true` is dropped on
  # KDE hosts by its lib.mkIf guard, so the two never clash.
  programs.seahorse.enable = false;

  # Optionally enable xserver
  services.xserver.enable = true;
}
