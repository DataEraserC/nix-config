# ===============================================================================
#
# xiaohuanxiong2api - SenseTime Raccoon (小浣熊) to OpenAI compatible API
# gateway with an embedded management panel on the same port.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.xiaohuanxiong2api`.
#
# Binds 0.0.0.0:1112 like the sibling gateways; openFirewall stays off so the
# port is reachable only over the VPN overlays and the LAN posture is unchanged.
# Upstream has no TLS, so keep it behind an authenticated reverse proxy when
# reaching it from an untrusted network.
#
# The API key (`/v1`, Authorization: Bearer) and the admin panel key are
# maintained in agenix (secrets/agenix/xiaohuanxiong2api-{api,admin-api}-key.age)
# and decrypted to /run/agenix/, 0600, owned by the service account. The NUR
# module loads both as systemd credentials and exports XHX_API_KEY and
# XHX_ADMIN_API_KEY, so an empty key never falls back to an unauthenticated
# endpoint. Read them with
#   sudo cat /run/agenix/xiaohuanxiong2api-api-key
#   sudo cat /run/agenix/xiaohuanxiong2api-admin-api-key
# Rotate with
#   just -f secrets/Justfile edit agenix/xiaohuanxiong2api-api-key.age   (sudo)
# followed by a service restart - the env-passed key is fixed at process start.
#
# The JSON config is generated into the store (upstream reads it once at start
# and never writes it back). Mutable state lives in /var/lib/xiaohuanxiong2api:
# accounts.json (the Raccoon account pool), model_catalog.json and
# checkin.json. Accounts are enrolled in the panel, so a redeploy keeps them.
#
# Check Service Status
#   systemctl status xiaohuanxiong2api
# Check logs
#   journalctl -u xiaohuanxiong2api --since "2 minutes ago"
# Probe the gateway
#   curl http://127.0.0.1:1112/healthz
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.xiaohuanxiong2api;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ nur-DataEraserC.nixosModules.xiaohuanxiong2api ];

  options.modules.xiaohuanxiong2api = {
    enable = lib.mkEnableOption "xiaohuanxiong2api Raccoon gateway and panel";
    host = lib.mkOption {
      type = lib.types.nonEmptyStr;
      description = "Bind address of the gateway; the host that uses this module must set it (port registry myvars.networking.services.xiaohuanxiong2api.hosts.<machine>.host).";
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port xiaohuanxiong2api listens on for both the API and the panel; the host that uses this module must set it (port registry myvars.networking.services.xiaohuanxiong2api.hosts.<machine>.port).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.xiaohuanxiong2api = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.xiaohuanxiong2api;
      host = cfg.host;
      port = cfg.port;
      openFirewall = false;
      # agenix-managed keys, loaded via systemd LoadCredential (agent2api style).
      apiKeyFile = "/run/agenix/xiaohuanxiong2api-api-key";
      adminApiKeyFile = "/run/agenix/xiaohuanxiong2api-admin-api-key";
    };
  };
}
