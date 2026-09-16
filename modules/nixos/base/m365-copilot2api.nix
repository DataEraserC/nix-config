# ===============================================================================
#
# M365 Copilot2API - Microsoft 365 Copilot to OpenAI/Anthropic compatible API gateway.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.m365Copilot2api`.
#
# Binds to 0.0.0.0:4141; reach the web console at http://<host-ip>:4141/
#
# Check Service Status
#   systemctl status m365-copilot2api
# Check logs
#   journalctl -u m365-copilot2api --since "2 minutes ago"
# Read the admin password
#   sudo cat /run/agenix/m365-copilot2api-admin-password
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.m365-copilot2api;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ nur-DataEraserC.nixosModules.m365-copilot2api ];

  options.modules.m365-copilot2api = {
    enable = lib.mkEnableOption "M365 Copilot2API gateway";
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.m365Copilot2api = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.m365-copilot2api;
      listenAddress = "0.0.0.0:4141";
      adminPasswordFile = "/run/agenix/m365-copilot2api-admin-password";
      requireStrongPassword = false;
    };
  };
}
