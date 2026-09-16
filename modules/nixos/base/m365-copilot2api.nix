# ===============================================================================
#
# M365 Copilot2API - Microsoft 365 Copilot to OpenAI/Anthropic compatible API gateway.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.m365Copilot2api`.
#
# Binds to 127.0.0.1:4141; reach the web console at http://127.0.0.1:4141/
# Set listenAddress = "0.0.0.0" plus openFirewall = true to expose it on the
# network; the console is plain HTTP, so keep a TLS reverse proxy in front.
#
# The adminPasswordFile secret seeds the console password on first start and
# again whenever its content changes; a password changed in the web console
# stays in effect until then.
#
# The masterKeyFile secret encrypts the refresh tokens in accounts.json (and
# enables the Microsoft Graph admin connection). Changing or removing it makes
# the already-stored tokens unreadable, so the accounts have to be authorized
# again.
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
      listenAddress = "127.0.0.1";
      port = 4141;
      adminPasswordFile = "/run/agenix/m365-copilot2api-admin-password";
      masterKeyFile = "/run/agenix/m365-copilot2api-master-key";
    };
  };
}
