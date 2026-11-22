# Binaries the niri keybindings and conf/scripts rely on that nothing else
# packages: the screenshot color picker needs grim/slurp/ImageMagick. The
# dropdown terminal runs ghostty (already installed) through ndrop.
{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    grim
    slurp
    imagemagick
  ];
}
