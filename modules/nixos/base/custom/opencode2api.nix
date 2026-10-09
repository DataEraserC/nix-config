# ===============================================================================
#
# opencode2api - OpenCode Zen and Zen Go API gateway with OpenAI/Anthropic compatibility.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.opencode2api`.
#
# Binds to 0.0.0.0:1101 for the API and 0.0.0.0:1102 for the WebUI (loopback
# was the upstream default; the wrapper exposes both), so exposure follows the
# host firewall posture. The WebUI is plain HTTP - keep a TLS reverse proxy in
# front when reaching it from another machine.
#
# The server automatically generates a random local API key on first start
# (stored in ${stateDir}/server.key). The WebUI bootstrap password is loaded
# from an agenix secret and migrated to an Argon2id hash on first start.
#
# Check Service Status
#   systemctl status opencode2api
# Check logs
#   journalctl -u opencode2api --since "2 minutes ago"
# Read the auto-generated server key
#   sudo cat /var/lib/opencode2api/server.key
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.opencode2api;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ nur-DataEraserC.nixosModules.opencode2api ];

  options.modules.opencode2api = {
    enable = lib.mkEnableOption "opencode2api gateway";
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port opencode2api listens on; the host that uses this module must set it (port registry network.services.opencode2api.port).";
    };
    webUiPort = lib.mkOption {
      type = lib.types.port;
      description = "WebUI listen port; the host that uses this module must set it (port registry network.services.opencode2api.adminPort).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.opencode2api = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.opencode2api;
      host = "0.0.0.0";
      port = cfg.port;
      webUi = {
        host = "0.0.0.0";
        port = cfg.webUiPort;
        enable = true;
        passwordFile = "/run/agenix/opencode2api-webui-password";
      };
      settings = {
        anonymous = true;
      };
    };
  };
}
