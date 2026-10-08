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

  # Auto-updates from nur-DataEraserC flow straight through here. The former
  # dev-branch override (HEXUXIU/M365-Copilot2API#93: withheld stream tails,
  # mid-rune snapshot splits, leaked citation markers) was dropped once the
  # upstream release carried those fixes — the maintainer closed #93 against
  # v0.7.0 (2026-09-27) and v0.7.1 added the stream/UTF-8 regression tests.
  # The override pinned only version + src while inheriting the base
  # vendorHash, so it broke as soon as an auto-update moved that hash.
  m365Copilot2api = nur-DataEraserC.packages.${system}.m365-copilot2api;
in
{
  imports = [ nur-DataEraserC.nixosModules.m365-copilot2api ];

  options.modules.m365-copilot2api = {
    enable = lib.mkEnableOption "M365 Copilot2API gateway";
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.m365Copilot2api = {
      enable = true;
      package = m365Copilot2api;
      listenAddress = "0.0.0.0";
      port = 1104;
      adminPasswordFile = "/run/agenix/m365-copilot2api-admin-password";
      masterKeyFile = "/run/agenix/m365-copilot2api-master-key";
    };
  };
}
