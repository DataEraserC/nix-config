# Dark-mode signal for non-GNOME sessions.
#
# Chromium/Electron and the xdg-desktop-portal Settings backend read the
# freedesktop appearance preference (`org.freedesktop.appearance
# color-scheme`). On GNOME that key is maintained by
# home/linux/gui/gnome-wayland/values/gnome.nix; a niri-only home otherwise
# reports "no preference", so Chromium falls back to its light palette even
# though the GTK settings.ini says prefer-dark.
#
# This only selects dark vs light. The catppuccin palette itself cannot reach
# Chrome's own UI: Chromium 157 paints its toolbar/tab strip with its built-in
# dark theme and ignores the GTK theme colours (verified under niri and with
# XDG_CURRENT_DESKTOP=GNOME; `catppuccin/chrome` is a separate browser theme).
{
  ...
}:
{
  dconf = {
    enable = true;
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };
}
