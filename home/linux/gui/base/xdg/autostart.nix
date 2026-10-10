{
  pkgs,
  ...
}:
let
  # Custom startup entry: runs the activated desktop startup script
  # (~/.config/scripts/startup, symlinked from desktop/conf/scripts by
  # desktop-tools.nix). Kept here instead of as a tracked .desktop so the Exec
  # path is resolved from the home-manager config rather than a machine-specific
  # repository path.
  #
  # The script is niri/wlroots-oriented (mpd, wayvnc/novnc, sway-audio-idle-inhibit
  # and friends), so it is only autostarted under the niri variant; GNOME and
  # KDE sessions do not depend on this file.
  startupDesktop = lib.optional config.modules.desktop.niri.enable (
    pkgs.writeText "startup.desktop" ''
      [Desktop Entry]
      Type=Application
      Name=Startup Script
      Exec=${config.home.homeDirectory}/.config/scripts/startup
      Hidden=false
      NoDisplay=false
      X-GNOME-Autostart-enabled=true
    ''
  );
in
{
  # XDG autostart entries. All of them are globally ordered after the
  # xdg-desktop-portal stack via `systemd.user.units."app-@autostart.service"`
  # in modules/nixos/desktop/xdg.nix, so sandboxed apps (nixpak: firefox,
  # telegram, ...) don't race the portal at login and end up with broken
  # FileChooser/OpenURI until manually restarted.
  xdg.autostart.enable = true;
  # This fixes nixpak sandboxed apps (like firefox) accessing mapped folders correctly
  xdg.autostart.entries = [
    "${pkgs.ghostty}/share/applications/com.mitchellh.ghostty.desktop"
    # "${pkgs.kitty}/share/applications/kitty.desktop"

    # nixpaks
    # "${pkgs.nixpaks.firefox}/share/applications/org.mozilla.firefox.desktop"
    # "${pkgs.nixpaks.telegram-desktop}/share/applications/org.telegram.desktop.desktop"
    "${pkgs.google-chrome}/share/applications/google-chrome.desktop"
  ];
}
