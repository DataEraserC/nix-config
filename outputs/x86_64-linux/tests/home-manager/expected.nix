{
  myvars,
  lib,
}:
let
  username = myvars.username;
  hosts = [
    "ai-gnome-wayland"
    "ai-kde-wayland"
    "ai-niri"
    "ruby"
  ];
in
lib.genAttrs hosts (_: "/home/${username}")
