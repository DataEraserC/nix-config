# ===============================================================================
#
# new-api - OpenAI-compatible LLM gateway with users, API tokens, quotas and logs.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.new-api` and adds:
#   - SQLite database in stateDir (default)
#   - Optional PostgreSQL/MySQL via database.type + database.dsn
#   - Session secret via agenix (`/run/agenix/new-api-session-secret`)
#   - Memory cache enabled by default
#
# Listens on port 1100 (the 1100 service series); default admin credentials are
# set on first login.
#
# Check Service Status
#   systemctl status new-api
# Check logs
#   journalctl -u new-api --since "2 minutes ago"
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.new-api;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ nur-DataEraserC.nixosModules.new-api ];

  options.modules.new-api = {
    enable = lib.mkEnableOption "new-api LLM gateway";
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port new-api listens on; the host that uses this module must set it (port registry myvars.networking.services.new-api.hosts.<machine>).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.new-api = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.new-api;
      port = cfg.port;
      master = true;
      sessionSecretFile = "/run/agenix/new-api-session-secret";
      openFirewall = false;
    };
  };
}
