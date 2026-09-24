# ===============================================================================
#
# mimocode2api - Xiaomi MiMo Code free models to OpenAI compatible API gateway.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.mimocode2api`.
#
# The upstream server always binds 0.0.0.0 (no bind address option); this host
# runs the firewall with only the VPN overlays as trusted interfaces, so the
# gateway stays reachable from Tailscale/ZeroTier/EasyTier only. Set
# openFirewall = true to expose it on plain LAN interfaces as well; the API is
# plain HTTP, so keep a TLS reverse proxy in front when exposing it.
#
# The generated client id persists in /var/lib/mimocode2api/client and is
# reused across restarts.
#
# Check Service Status
#   systemctl status mimocode2api
# Check logs
#   journalctl -u mimocode2api --since "2 minutes ago"
# Probe the gateway
#   curl http://127.0.0.1:4144/health
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.mimocode2api;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ nur-DataEraserC.nixosModules.mimocode2api ];

  options.modules.mimocode2api = {
    enable = lib.mkEnableOption "mimocode2api gateway";
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.mimocode2api = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.mimocode2api;
      port = 4144;
      openFirewall = false;
    };
  };
}
