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

  # Temporary bump: nur-DataEraserC still pins v0.7.0, whose stream_text.go
  # withholds the tail of every streamed reply and whose commonPrefixLen()
  # slices cumulative snapshots mid-rune (HEXUXIU/M365-Copilot2API#93).
  # d6d5a56 is the tip of the unreleased dev-pr-integration branch, which
  # fixes both. Drop this override once nur-DataEraserC ships a release that
  # contains those fixes.
  m365Copilot2api = nur-DataEraserC.packages.${system}.m365-copilot2api.overrideAttrs (_: {
    version = "0.7.0-unstable-2026-09-15";
    src = pkgs.fetchFromGitHub {
      owner = "HEXUXIU";
      repo = "M365-Copilot2API";
      rev = "d6d5a567bf394578c66f0e09c7d16275dedc2355";
      hash = "sha256-VjT7ziRgTQxW5P37fUNtr8D13SNkUqC1QljRGkZIFww=";
    };
  });
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
      port = 4141;
      adminPasswordFile = "/run/agenix/m365-copilot2api-admin-password";
      masterKeyFile = "/run/agenix/m365-copilot2api-master-key";
    };
  };
}
