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
# Data lives in /var/lib/sub-store (root.json + <name>.json - SUB_STORE_DATA_BASE_PATH):
#   systemd StateDirectory, so it survives service restarts, reboots and nixos-rebuild
#   (only RuntimeDirectory would be volatile). Files are written mode 0600 (UMask 0077).
#
# Web panel (modules.sub-store.frontend.enable, default on):
#   Serves the official Sub-Store PWA (Sub-Store-Front-End release) from the same
#   service on <frontend.port> (default http://127.0.0.1:24501/). The release's
#   code-level default backend (https://sub.store) is rewritten at build time to
#   derive from location.hostname at runtime, so the API is always called on the
#   same host:24500 the panel page was opened with - independent of what cfg.host
#   binds (idols-ai overrides host to 0.0.0.0). Settings > Custom Backend API can
#   still override it. API and panel are unauthenticated: the module default binds
#   loopback only, so any wider bind (e.g. 0.0.0.0) must be firewalled.
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

  # Official web panel (PWA). Keep the version aligned with pkgs.sub-store - both
  # follow the upstream release train, so 2.22.1 pairs with backend 2.22.26.
  frontendVersion = "2.22.1";
  frontendRelease = pkgs.fetchzip {
    url = "https://github.com/sub-store-org/Sub-Store-Front-End/releases/download/${frontendVersion}/dist.zip";
    hash = "sha256-N/qDGP//4RqwBNK2x+Q+AfTzBCtFPYuqmHOruO/KfVU=";
  };
  # Rewrite the release's code-level default backend (https://sub.store) so the
  # API host follows location.hostname at runtime - i.e. always the host the
  # panel page was opened with. The whole patch (sed rewrite + guards + sw.js
  # cache marker) lives in sub-store-frontend-patch.sh and receives the module
  # values as plain arguments, keeping this derivation free of nested quoting.
  frontendDist = pkgs.runCommand "sub-store-frontend-${frontendVersion}" { } ''
    mkdir -p "$out"
    cp -r ${frontendRelease}/. "$out"
    chmod -R u+w "$out"
    bash ${./sub-store-frontend-patch.sh} "$out" ${toString cfg.port} "${frontendVersion}"
  '';

  # Parse a single-unit duration ("30min" / "2h" / "1day") into whole minutes.
  # Only forced when autoRefresh is enabled (the env merge is a lazy mkIf).
  autoRefreshMinutes =
    let
      m = builtins.match "([0-9]+)(min|h|hr|day)" cfg.autoRefresh.interval;
    in
    if m == null then
      throw ''modules.sub-store.autoRefresh.interval: "${cfg.autoRefresh.interval}" is not a supported duration; use one unit, e.g. "30min", "2h" or "1day"''
    else
      let
        count = builtins.fromJSON (builtins.elemAt m 0);
        unit = builtins.elemAt m 1;
      in
      count
      * (
        if unit == "min" then
          1
        else if unit == "h" || unit == "hr" then
          60
        else
          1440
      );

  # A cron minute field can only step by divisors of 60 (the hours field by
  # divisors of 24), so anything else fails the eval with the accepted values.
  cronEveryMinutes =
    minutes:
    if minutes > 0 && minutes < 60 && 60 / minutes * minutes == 60 then
      "*/${toString minutes} * * * *"
    else if
      minutes >= 60 && minutes / 60 * 60 == minutes && 24 / (minutes / 60) * (minutes / 60) == 24
    then
      "0 */${toString (minutes / 60)} * * *"
    else
      throw "modules.sub-store.autoRefresh.interval: ${toString minutes}min cannot be expressed as a cron step; use a divisor of 60 (1 2 3 4 5 6 10 12 15 20 30 60) or full hours dividing a day (120 180 240 360 480 720 1440)";

  # SUB_STORE_PRODUCE_CRON = "<cron>,<type>,<name>[;<cron>,<type>,<name>...]" - the
  # backend splits entries on ';' and fields on ',' (so the cron expression itself
  # must contain no commas), then runs sn({type, name}) per entry on that schedule.
  produceCron = lib.concatMapStringsSep ";" (
    name: "${cronEveryMinutes autoRefreshMinutes},sub,${name}"
  ) cfg.autoRefresh.subs;
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
        Bind address of the backend API and of the web panel. The API has no
        authentication, so the default stays on loopback; set "0.0.0.0" to
        listen on all interfaces only when the host firewall restricts access
        to trusted interfaces (idols-ai does this).
      '';
    };

    frontend = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Serve the official Sub-Store web panel (static PWA) from the same
          service on a separate port (see `frontend.port`), with its default
          backend URL patched to call the API on the host this page is opened
          with.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        # keep the panel next to the API on 24500
        default = 24501;
        description = "TCP port of the Sub-Store web panel (frontend static server).";
      };
    };

    autoRefresh = {
      enable = lib.mkEnableOption ''
        periodic upstream refresh via SUB_STORE_PRODUCE_CRON, which re-fetches
        every subscription listed in `subs` and updates its #cacheKey disk cache
      '';

      interval = lib.mkOption {
        type = lib.types.str;
        default = "60min";
        example = "2h";
        description = ''
          Time between refreshes as a duration with a single unit: minutes
          (`30min`), hours (`2h`) or days (`1day`); seconds are not supported.
          It is converted into the cron part of SUB_STORE_PRODUCE_CRON, so the
          value must be a divisor of 60 minutes or full hours dividing a day
          (the eval fails otherwise). Upstream fetches are additionally capped
          by Sub-Store's 1h in-memory cache, so sub-hour intervals do not
          re-download more often than hourly.
        '';
      };

      subs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "iKuuu1"
          "iKuuu2"
        ];
        description = ''
          Sub-Store subscription names to refresh on the interval, as shown in
          the panel and by `GET /api/subs` (`data[].name`). Each name becomes
          one `<interval>,sub,<name>` entry in SUB_STORE_PRODUCE_CRON.
        '';
      };
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
    # autoRefresh without names would set an empty (silently ignored)
    # SUB_STORE_PRODUCE_CRON - fail the eval instead of silently doing nothing.
    assertions = lib.optional cfg.autoRefresh.enable {
      assertion = cfg.autoRefresh.subs != [ ];
      message = "modules.sub-store.autoRefresh.enable requires autoRefresh.subs to list at least one subscription name";
    };

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
      // lib.optionalAttrs cfg.frontend.enable {
        # Static panel assets; the backend starts its frontend server for them on a
        # separate port (API and panel stay independent, UI calls the API by URL).
        SUB_STORE_FRONTEND_PATH = frontendDist;
        SUB_STORE_FRONTEND_HOST = cfg.host;
        SUB_STORE_FRONTEND_PORT = toString cfg.frontend.port;
      }
      // lib.optionalAttrs cfg.autoRefresh.enable {
        SUB_STORE_PRODUCE_CRON = produceCron;
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
