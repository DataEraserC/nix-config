# ===============================================================================
#
# CLIProxyAPI - proxy that exposes Gemini/Claude/Codex/Grok as OpenAI-compatible APIs.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.cliproxyapi` and adds:
#   - an offline management panel from `cliproxyapi-management-center-bin`, the
#     prebuilt upstream release asset (no npm build, no GitHub download at runtime)
#   - a management key managed by agenix (`/run/agenix/cliproxyapi-management.key`)
#   - `mutableConfig = true` so panel/API edits survive restarts
#
# Binds to 0.0.0.0:1105; reach the panel at http://<host-ip>:1105/management.html
# (access restricted by firewall). Every management API request needs the
# management key, so `allowRemote` only lifts the loopback-only check that would
# otherwise answer 403 to a browser connecting from another host.
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
      managementCenterPackage = nur-DataEraserC.packages.${system}.cliproxyapi-management-center-bin;
      host = "0.0.0.0";
      port = 1105;
      allowRemote = true;
      managementKeyFile = "/run/agenix/cliproxyapi-management.key";
    };
  };
}
