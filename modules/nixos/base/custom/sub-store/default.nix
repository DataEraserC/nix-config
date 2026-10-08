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
#   same host the panel page was opened with - independent of what cfg.host
#   binds (idols-ai overrides host to 0.0.0.0). With auth.enable Caddy serves the
#   panel and /api/* on frontend.port, so the call stays same-origin (no CORS
#   preflight can meet the password prompt); otherwise it uses cfg.port as before.
#   Settings > Custom Backend API can still override it.
#
# Authentication (modules.sub-store.auth.enable, off by default):
#   Sub-Store has no built-in auth, so the module can front the API and the panel
#   with a Caddy reverse proxy enforcing Basic Auth (htpasswd lines in auth.file).
#   Sub-Store then binds loopback-internal ports while Caddy holds the public
#   ones. Passwordless on purpose: loopback clients (dae, the local panel) and
#   every GET /download/* - subscription links stay direct links for any client.
#   Password: the panel page and the remaining management API, remotely.
#   The panel site doubles as the panel's API origin: Caddy routes /api/* and
#   /download/* on frontend.port to the backend and everything else to the
#   static frontend, so the browser never sends a cross-origin (preflighted)
#   request to the authenticated API - it replays the page's credentials.
#   Without auth.enable the legacy model applies: loopback-only default bind, or
#   a wider bind guarded solely by the host firewall (see openFirewall).
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
    bash ${./sub-store-frontend-patch.sh} "$out" ${toString panelApiPort} "${frontendVersion}"
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

  # Caddy site address for a public port. A wildcard bind must stay hostless
  # (":24500") - "0.0.0.0:24500" would install a literal Host matcher that only
  # requests to Host 0.0.0.0 satisfy. A concrete bind keeps its hostname.
  siteAddr =
    port:
    if cfg.host == "0.0.0.0" || cfg.host == "::" then
      ":${toString port}"
    else
      "${cfg.host}:${toString port}";

  # Where Sub-Store itself listens: with auth enabled it is loopback-only and
  # Caddy holds the public ports, otherwise Sub-Store binds cfg.host directly.
  apiHost = if cfg.auth.enable then "127.0.0.1" else cfg.host;
  apiPort = if cfg.auth.enable then cfg.auth.upstreamApiPort else cfg.port;
  frontendHost = if cfg.auth.enable then "127.0.0.1" else cfg.host;
  frontendPort = if cfg.auth.enable then cfg.auth.upstreamFrontendPort else cfg.frontend.port;

  # Port the patched panel backend defaults to (the host always follows
  # location.hostname). Under auth.enable it must be the frontend's own port:
  # Caddy routes /api/* there too, keeping API calls same-origin so no CORS
  # preflight runs into Basic Auth. Without auth the public API port as before.
  panelApiPort = if cfg.auth.enable then cfg.frontend.port else cfg.port;
in
{
  options.modules.sub-store = {
    enable = lib.mkEnableOption "Sub-Store subscription manager (Clash -> v2ray conversion for dae)";

    port = lib.mkOption {
      type = lib.types.port;
      # Upstream Sub-Store listens on 3000, the port new-api used to occupy on
      # this host, so a free high port was picked instead - dae already
      # downloads from 127.0.0.1:24500, do not move it lightly.
      default = 24500;
      description = "TCP port of the Sub-Store backend API.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Bind address of the backend API and of the web panel, used verbatim
        when auth.enable is off (there is no authentication then, so the default
        stays on loopback and any wider bind must be firewalled to trusted
        interfaces - idols-ai does this). With auth.enable, Caddy takes this
        bind on the public ports while Sub-Store moves to loopback-internal
        ports.
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

    auth = {
      enable = lib.mkEnableOption ''
        Basic Auth (via a Caddy reverse proxy) in front of the API and the panel.
        Sub-Store itself has no auth; when enabled it binds loopback-internal
        ports (auth.upstreamApiPort / auth.upstreamFrontendPort) while Caddy
        holds the public ports. Loopback clients and GET /download/* - i.e. dae
        and every subscription link - stay passwordless.
      '';

      file = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Runtime path of the htpasswd file imported by Caddy's basic_auth: one
          or more `<user> <bcrypt hash>` lines, produced by
          `caddy hash-password --plaintext '<password>'`. Point this at an
          agenix secret so the hash never lands in this repository.
        '';
      };

      upstreamApiPort = lib.mkOption {
        type = lib.types.port;
        default = 24510;
        description = "Loopback port of the API while auth.enable is on; Caddy proxies `port` to it.";
      };

      upstreamFrontendPort = lib.mkOption {
        type = lib.types.port;
        default = 24511;
        description = "Loopback port of the panel while auth.enable is on; Caddy proxies `frontend.port` to it.";
      };
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open `port` (and `frontend.port` when the frontend is on) in the host
        firewall for every interface, not just `trustedInterfaces`. Requires
        auth.enable - exposing the unauthenticated management API and panel
        beyond trusted interfaces would be unsafe.
      '';
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
    # auth without an htpasswd file would deploy an unauthenticated Caddy, and
    # openFirewall without auth would expose that same unprotected surface to
    # every interface - both are configuration bugs, so fail the eval on them.
    assertions =
      lib.optional cfg.autoRefresh.enable {
        assertion = cfg.autoRefresh.subs != [ ];
        message = "modules.sub-store.autoRefresh.enable requires autoRefresh.subs to list at least one subscription name";
      }
      ++ lib.optional cfg.auth.enable {
        assertion = cfg.auth.file != null;
        message = "modules.sub-store.auth.enable requires auth.file - htpasswd lines from `caddy hash-password`, ideally via an agenix secret";
      }
      ++ lib.optional cfg.openFirewall {
        assertion = cfg.auth.enable;
        message = "modules.sub-store.openFirewall requires auth.enable - without Basic Auth the management API and panel must stay limited to trusted interfaces";
      };

    systemd.services.sub-store = {
      description = "Sub-Store subscription manager";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        SUB_STORE_BACKEND_API_HOST = apiHost;
        SUB_STORE_BACKEND_API_PORT = toString apiPort;
        SUB_STORE_DATA_BASE_PATH = dataDir;
      }
      // lib.optionalAttrs cfg.frontend.enable {
        # Static panel assets; the backend starts its frontend server for them on a
        # separate port (API and panel stay independent, UI calls the API by URL).
        SUB_STORE_FRONTEND_PATH = frontendDist;
        SUB_STORE_FRONTEND_HOST = frontendHost;
        SUB_STORE_FRONTEND_PORT = toString frontendPort;
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

    # Basic Auth front: with auth.enable, Caddy holds the public ports on cfg.host
    # while Sub-Store runs on loopback behind it (apiHost/frontendHost above).
    # The API site skips the prompt for GET /download/* (subscription links stay
    # direct links) and for loopback callers (dae, local panel); the panel site
    # skips it for loopback and /download/* too, then splits traffic: /api/* and
    # /download/* to the backend, everything else to the static frontend - the
    # panel's own origin serves its API, so authenticated XHR never preflights.
    # Every other remote request needs auth.file.
    services.caddy = lib.mkIf cfg.auth.enable {
      enable = true;
      enableReload = true;
      # Port-only vhosts over plain HTTP - never touch the ACME/TLS machinery.
      globalConfig = "auto_https disable_certs";
      virtualHosts = {
        ${siteAddr cfg.port} = {
          extraConfig = ''
            @apiAuth {
              not {
                path_regexp ^/download/
              }
              not {
                remote_ip 127.0.0.1 ::1
              }
            }
            basic_auth @apiAuth {
              import ${cfg.auth.file}
            }
            reverse_proxy http://127.0.0.1:${toString cfg.auth.upstreamApiPort}
          '';
        };
        ${siteAddr cfg.frontend.port} = {
          extraConfig = ''
            @panelAuth {
              not {
                path_regexp ^/download/
              }
              not {
                remote_ip 127.0.0.1 ::1
              }
            }
            basic_auth @panelAuth {
              import ${cfg.auth.file}
            }
            # Same-origin panel backend: the JS builds its API base from
            # location.hostname + frontend.port (panelApiPort above), so route
            # the API here instead of making the browser cross port 24500,
            # where its preflight would meet Basic Auth and CORS would hide it.
            @panelApi path /api/*
            reverse_proxy @panelApi http://127.0.0.1:${toString cfg.auth.upstreamApiPort}
            @panelDl path /download/*
            reverse_proxy @panelDl http://127.0.0.1:${toString cfg.auth.upstreamApiPort}
            reverse_proxy http://127.0.0.1:${toString cfg.auth.upstreamFrontendPort}
          '';
        };
      };
    };

    # The proxy is part of the local chain (dae -> caddy -> sub-store), so bring
    # it up with the same ordering guarantee as the converter itself.
    systemd.services.caddy = lib.mkIf cfg.auth.enable {
      wants = [ "sub-store.service" ];
      after = [ "sub-store.service" ];
    };

    # dae fetches its subscriptions exactly once (at startup/reload), so make sure
    # the local converter - and, with auth.enable, the Caddy front dae now reaches
    # it through - is started and reachable before dae does.
    systemd.services.dae = lib.mkIf (config.services.dae.enable or false) {
      wants = [ "sub-store.service" ] ++ lib.optional cfg.auth.enable "caddy.service";
      after = [ "sub-store.service" ] ++ lib.optional cfg.auth.enable "caddy.service";
    };

    # openFirewall widens exposure beyond trustedInterfaces; the assertions above
    # guarantee that can only happen with Basic Auth in front.
    networking.firewall.allowedTCPPorts =
      lib.optional cfg.openFirewall cfg.port
      ++ lib.optional (cfg.openFirewall && cfg.frontend.enable) cfg.frontend.port;
  };
}
