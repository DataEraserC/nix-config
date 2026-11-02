# ===============================================================================
#
# Agent2API - multi-provider subscription accounts to OpenAI/Anthropic
# compatible API gateway, with a web management panel.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.agent2api`, and pins the headless server package
# (`agent2api-server`) rather than the Tauri desktop build: same gateway, no
# webkit/gtk in the closure.
#
# Binds to 0.0.0.0:1108 and serves both the OpenAI-compatible API (/v1/*) and
# the panel on that single port. The host firewall only trusts the VPN overlays
# (tailscale/zerotier/easytier), so the panel is not exposed to the LAN; the
# API and panel are plain HTTP, so keep a TLS reverse proxy in front when
# reaching them from an untrusted network.
#
# The adminPasswordFile secret seeds the panel administrator on first start and
# again whenever its content changes (the password is stored as a bcrypt hash,
# so rotating the file takes effect on the next restart). The panel captcha is
# off: the panel is reachable over the VPN only and the password is a random
# agenix value.
#
# The gateway fails closed: /v1/* answers 401 until an API key is created in the
# panel, which is the intended posture for a host that stores provider
# credentials. State (SQLite database with accounts, API keys, request logs, and
# the credential encryption key) lives in /var/lib/agent2api, preserved by the
# host's impermanence setup.
#
# Set listenAddress, panelPort or allowNoKey in the wrapper below when a host
# needs a different split; hosts only toggle `modules.agent2api.enable` and set
# `modules.agent2api.port` from the port registry
# (myvars.networking.services.agent2api.hosts.<machine>.port).
#
# Check Service Status
#   systemctl status agent2api
# Check logs
#   journalctl -u agent2api --since "2 minutes ago"
# Read the admin password
#   sudo cat /run/agenix/agent2api-admin-password
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.agent2api;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ nur-DataEraserC.nixosModules.agent2api ];

  options.modules.agent2api = {
    enable = lib.mkEnableOption "Agent2API gateway";
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port Agent2API listens on for both the API and the panel; the host that uses this module must set it (port registry myvars.networking.services.agent2api.hosts.<machine>.port).";
    };
    panelPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Serve the management panel on its own port instead of `port`, so only the API port has to be reachable; must differ from `port`.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.agent2api = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.agent2api-server;
      host = "0.0.0.0";
      inherit (cfg) port panelPort;
      adminUser = "admin";
      adminPasswordFile = "/run/agenix/agent2api-admin-password";
      captcha = false;
      openFirewall = false;
    };
  };
}
