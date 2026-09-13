# ===============================================================================
#
# CLIProxyAPI - proxy that exposes Gemini/Claude/Codex/Grok as OpenAI-compatible APIs.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.cliproxyapi` and adds:
#   - an offline management panel served from `cliproxyapi-management-center`
#     (no GitHub download at runtime)
#   - a management key managed by agenix (`/run/agenix/cliproxyapi-management.key`)
#   - `mutableConfig = true` so panel/API edits survive restarts
#
# By default, binds to 0.0.0.0:8317; reach the panel at
# http://<host-ip>:8317/management.html (access restricted by firewall).
#
# Check Service Status
#   systemctl status cliproxyapi
# Check logs
#   journalctl -u cliproxyapi --since "2 minutes ago"
# Read the management key
#   sudo cat /run/agenix/cliproxyapi-management.key
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.cliproxyapi;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ nur-DataEraserC.nixosModules.cliproxyapi ];

  options.modules.cliproxyapi = {
    enable = lib.mkEnableOption "CLIProxyAPI proxy with an offline management panel";
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.cliproxyapi = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.cliproxyapi;
      managementCenterPackage = nur-DataEraserC.packages.${system}.cliproxyapi-management-center;
      host = "0.0.0.0";
      managementKeyFile = "/run/agenix/cliproxyapi-management.key";
    };
  };
}
