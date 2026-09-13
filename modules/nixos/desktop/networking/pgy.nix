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
  nur-DataEraserC,
  pkgs,
  ...
}:
{
  imports = [
    nur-DataEraserC.nixosModules.pgy
  ];
  services.dataEraserc.pgy = {
    enable = true;
    package = nur-DataEraserC.packages.${pkgs.system}.pgy_fhs;
    stateDir = "/var/lib/pgyvpn";
    configFile = "/var/lib/pgyvpn/config.ini";
    logDir = "/var/log/oray";
  };
}
