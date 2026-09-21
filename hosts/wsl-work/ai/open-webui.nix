{
  pkgs,
  pkgs-stable,
  pkgs-latest,
  ...
}:
{
  services.open-webui = {
    package = pkgs.open-webui;
    enable = false;
    host = "0.0.0.0";
  };
}
