{
  pkgs,
  pkgs-master,
  config,
  lib,
  ...
}:
let
  # Custom startup entry: runs the activated desktop startup script
  # (~/.config/scripts/startup, symlinked from desktop/conf/scripts by
  # desktop-tools.nix). Kept here instead of as a tracked .desktop so the Exec
  # path is resolved from the home-manager config rather than a machine-specific
  # repository path.
  startupDesktop = pkgs.writeText "startup.desktop" ''
    [Desktop Entry]
    Type=Application
    Name=Startup Script
    Exec=${config.home.homeDirectory}/.config/scripts/startup
    Hidden=false
    NoDisplay=false
    X-GNOME-Autostart-enabled=true
  '';
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
    #"${pkgs.foot}/share/applications/foot.desktop"
    #"${pkgs.alacritty}/share/applications/Alacritty.desktop"
    #"${pkgs.ghostty}/share/applications/com.mitchellh.ghostty.desktop"

    "${pkgs-master.clash-verge-rev}/share/applications/clash-verge.desktop"

    # Custom startup script
    startupDesktop

    # nixpaks
    #"${pkgs.nixpaks.firefox}/share/applications/org.mozilla.firefox.desktop"
    #"${pkgs.nixpaks.telegram-desktop}/share/applications/org.telegram.desktop.desktop"
  ]
  ++ (
    if pkgs.stdenv.hostPlatform.isx86_64 then
      [ "${pkgs.google-chrome}/share/applications/google-chrome.desktop" ]
    else
      [ "${pkgs.chromium}/share/applications/chromium-browser.desktop" ]
  );
}
