# ===============================================================================
#
# Oray PgyVisitor software-defined networking client daemon (pgyvpn_svr)
#
# Check Service Status
#   systemctl status pgyvpn
# Check logs
#   journalctl -u pgyvpn --since "2 minutes ago"
{
  config,
  lib,
  nur-DataEraserC,
  pkgs,
  ...
}:
let
  cfg = config.modules.pgy;
in
{
  imports = [
    nur-DataEraserC.nixosModules.pgy
  ];

  options.modules.pgy = {
    enable = lib.mkEnableOption "Oray PgyVisitor SDN client";
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.pgy = {
      enable = true;
      package = nur-DataEraserC.packages.${pkgs.system}.pgy;
      stateDir = "/var/lib/pgyvpn";
      configFile = "/var/lib/pgyvpn/config.ini";
      logDir = "/var/log/oray";
    };
  };
}
