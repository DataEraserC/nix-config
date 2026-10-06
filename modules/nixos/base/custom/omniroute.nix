# ===============================================================================
#
# omniroute - OmniRoute unified LLM gateway (OpenAI/Anthropic-compatible
# aggregator with dashboard and MITM proxy).
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.omniroute`.
#
# Binds 0.0.0.0:20128 like the sibling gateways; idols-ai keeps openFirewall
# off (see hosts/idols-ai firewall note), so exposure follows the LAN posture
# only. REQUIRE_API_KEY=true satisfies the upstream non-loopback API key
# guard for the 0.0.0.0 bind (upstream Docker image does the same).
#
# Fresh install: the management bootstrap token is printed to the journal on
# first start (journalctl -u omniroute); with INITIAL_PASSWORD unset the
# dashboard falls back to CHANGEME - change it after first login (upstream
# docs 12.5). Mutable state lives in /var/lib/omniroute (DATA_DIR:
# storage.sqlite, generated server.env secrets, logs).
#
# The unit is Type=notify: upstream sends READY/WATCHDOG through
# systemd-notify after the socket listens, with WatchdogSec=120s covering
# the upstream 60s ping period.
#
# Check Service Status
#   systemctl status omniroute
# Check logs / bootstrap token
#   journalctl -fu omniroute
#   sudo journalctl -u omniroute | grep -i token
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.omniroute;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ nur-DataEraserC.nixosModules.omniroute ];

  options.modules.omniroute = {
    enable = lib.mkEnableOption "OmniRoute unified LLM gateway";
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.omniroute = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.omniroute;
      host = "0.0.0.0";
      port = 20128;
      extraEnvironment.REQUIRE_API_KEY = "true";
    };
  };
}
