# ===============================================================================
#
# meoo2api - Meoo model gateway to OpenAI compatible API, with an account
# management console on the same port.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.meoo2api`.
#
# Binds to 0.0.0.0:1110; the OpenAI compatible API lives under /v1 and the
# console is served at /. The host firewall only trusts the VPN overlays
# (tailscale/zerotier/easytier), so the console is not exposed to the LAN; the
# API and console are plain HTTP, so keep a TLS reverse proxy in front when
# reaching them from an untrusted network.
#
# Without adminPasswordFile the server generates a random administrator
# password on first start and prints it once to the journal; read it with
#   sudo journalctl -u meoo2api | grep '管理端初始密码'
# Accounts are added through the console (browser device authorization), so
# state.json in /var/lib/meoo2api holds the accounts, project keys, client API
# keys, usage log and settings.
#
# Check Service Status
#   systemctl status meoo2api
# Check logs
#   journalctl -u meoo2api --since "2 minutes ago"
# Probe the gateway
#   curl http://127.0.0.1:1110/healthz
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.meoo2api;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ nur-DataEraserC.nixosModules.meoo2api ];

  options.modules.meoo2api = {
    enable = lib.mkEnableOption "meoo2api gateway";
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port meoo2api listens on for both the API and the console; the host that uses this module must set it (port registry myvars.networking.services.meoo2api.hosts.<machine>.port).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.meoo2api = {
      enable = true;
      # meoo2api-firefox carries the Referrer-Policy: same-origin patch so
      # Firefox console logins keep a real Origin (upstream no-referrer makes
      # Firefox send Origin: null -> 403). Drop back to plain meoo2api once
      # upstream fixes the header; see the package's AGENTS.md for criteria.
      package = nur-DataEraserC.packages.${system}.meoo2api-firefox;
      host = "0.0.0.0";
      port = cfg.port;
      openFirewall = false;
    };
  };
}
