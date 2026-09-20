# ===============================================================================
#
# opencode2api - OpenCode Zen and Zen Go API gateway with OpenAI/Anthropic compatibility.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.opencode2api`.
#
# Binds to 127.0.0.1:8080 for the API and 127.0.0.1:8081 for the WebUI.
# Set host = "0.0.0.0" plus openFirewall = true to expose on the network;
# the WebUI is plain HTTP, so keep a TLS reverse proxy in front.
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
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.opencode2api = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.opencode2api;
      host = "0.0.0.0";
      port = 4142;
      webUi = {
        host = "0.0.0.0";
        port = 4143;
        enable = true;
        passwordFile = "/run/agenix/opencode2api-webui-password";
      };
      settings = {
        anonymous = true;
      };
    };
  };
}
