{
  pkgs,
  ...
}:
{
  # sqlite comes from the shared home/base/tui/dev-tools.nix.
  home.packages = with pkgs; [
    yutto
  ];
}
