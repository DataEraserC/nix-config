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
  # 1100-series ports, declared once and applied both to `settings` (which also drives
  # the module's firewall rule) and to the command line - see extraArgs below.
  apiPort = 1101;
  webUiPort = 1102;
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
      port = apiPort;
      webUi = {
        host = "0.0.0.0";
        port = webUiPort;
        enable = true;
        passwordFile = "/run/agenix/opencode2api-webui-password";
      };
      settings = {
        anonymous = true;
      };
      # /var/lib/opencode2api/config.json is seeded only once (mutableConfig defaults to
      # true): an already-seeded file keeps winning over `settings`, so a host whose file
      # dates from the 4142/4143 era still listens there and only logs a single
      # "keeps winning" warning on the first start after the change. The command-line
      # flags override that file (verified against opencode2api v1.3.7: -listen and
      # -web-listen win over config.json, and the effective values are written back), so
      # the ports above take effect without discarding WebUI-managed state.
      extraArgs = [
        "-listen"
        "0.0.0.0:${toString apiPort}"
        "-web-listen"
        "0.0.0.0:${toString webUiPort}"
      ];
    };
  };
}
