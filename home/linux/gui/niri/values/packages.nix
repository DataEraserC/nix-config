# Binaries the niri keybindings and conf/scripts rely on that nothing else
# packages: the screenshot color picker (grim/slurp/ImageMagick) and the
# dropdown terminal host (foot; the ndrop wrapper itself comes from
# niri/default.nix via the NUR).
{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    grim
    slurp
    imagemagick
    foot
  ];
}
