# ===============================================================================
#
# Sub-Store - advanced subscription manager (https://github.com/sub-store-org/Sub-Store).
#
# Purpose here: dae cannot parse Clash-YAML subscriptions, so dae is pointed at
#   http://127.0.0.1:<port>/download/<name>/v2ray
# which Sub-Store converts into a base64 list of v2ray URIs (the format dae accepts).
# The upstream Clash links are registered once via POST /api/subs (see below).
#
# Uses the nixpkgs package (pkgs.sub-store, bundled backend; no frontend assets).
# Data lives in /var/lib/sub-store (root.json + <name>.json - SUB_STORE_DATA_BASE_PATH).
#
# Check Service Status
#   systemctl status sub-store
# Check logs
#   journalctl -u sub-store --since "2 minutes ago"
# Register an upstream subscription (once)
#   curl -X POST http://127.0.0.1:24500/api/subs -H 'Content-Type: application/json' \
#     -d '{"name":"ikuuu","url":"https://example.com/sub?token=xxx"}'
# ===============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.sub-store;
  dataDir = "/var/lib/sub-store";
in
{
  options.modules.sub-store = {
    enable = lib.mkEnableOption "Sub-Store subscription manager (Clash -> v2ray conversion for dae)";

    port = lib.mkOption {
      type = lib.types.port;
      # new-api already binds 0.0.0.0:3000 on this host and upstream's default
      # (3000) would collide with it, so pick a free port instead.
      default = 24500;
      description = "TCP port of the Sub-Store backend API.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Bind address of the Sub-Store backend API. The API has no
        authentication, so keep it on loopback unless you front it with
        something else.
      '';
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        SUB_STORE_BACKEND_DEFAULT_PROXY = "http://127.0.0.1:7890";
      };
      description = ''
        Extra `SUB_STORE_*` environment variables passed to the service, e.g.
        SUB_STORE_BACKEND_DEFAULT_PROXY to fetch upstream subscriptions through
        a local proxy.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.sub-store = {
      description = "Sub-Store subscription manager";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        SUB_STORE_BACKEND_API_HOST = cfg.host;
        SUB_STORE_BACKEND_API_PORT = toString cfg.port;
        SUB_STORE_DATA_BASE_PATH = dataDir;
      }
      // cfg.extraEnvironment;
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.sub-store}";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        StateDirectory = "sub-store";
        # Relative default paths (e.g. mmdb caches) then land in the writable state dir.
        WorkingDirectory = dataDir;
        UMask = "0077";
        # hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
      };
    };

    # dae fetches its subscriptions exactly once (at startup/reload), so make sure
    # the local converter is started - and reachable - before dae does.
    systemd.services.dae = lib.mkIf (config.services.dae.enable or false) {
      wants = [ "sub-store.service" ];
      after = [ "sub-store.service" ];
    };
  };
}
