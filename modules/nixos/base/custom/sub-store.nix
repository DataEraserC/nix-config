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
  # Static local origin: shown in help texts, and the fallback when the page has
  # no hostname (file://). Deliberately NOT derived from cfg.host - on hosts
  # bound to 0.0.0.0 that value is not connectable from a browser; the runtime
  # code default is rewritten below to derive from location.hostname instead.
  staticOrigin = "http://127.0.0.1:${toString cfg.port}";
  # The release references the official backend in TWO code paths (a constant and
  # the `|| fallback` used when the hostAPI list is empty - the one that actually
  # runs on first visit) plus several i18n help texts. Rewrite them all so the
  # panel only ever talks to this local backend, then turn every quoted code-level
  # occurrence into `http://${location.hostname}:<port>` so the API host always
  # matches the host the page was opened with (127.0.0.1, LAN IP, SSH tunnel, ...).
  frontendDist = pkgs.runCommand "sub-store-frontend-${frontendVersion}" { } ''
    mkdir -p "$out"
    cp -r ${frontendRelease}/. "$out"
    chmod -R u+w "$out"
    # 1) official URL -> local origin (code paths + help texts)
    find "$out" -name '*.js' -exec sed -i 's#https://sub\.store#${staticOrigin}#g' {} +
    if grep -rFq 'https://sub.store' "$out" --include='*.js'; then
      echo "sub-store-frontend: official backend reference left over" >&2
      exit 1
    fi
    # 2) quote-delimited occurrences are code-level defaults -> location.hostname
    #    form. Help texts embed the origin unquoted and stay static.
    staticBefore=$(grep -rhoF '"http://127.0.0.1:${toString cfg.port}"' "$out" --include='*.js' | wc -l || true)
    if [ "$staticBefore" -lt 2 ]; then
      echo "sub-store-frontend: expected >= 2 quoted code defaults, found $staticBefore" >&2
      exit 1
    fi
    find "$out" -name '*.js' -exec sed -i 's#"http://127\.0\.0\.1:${toString cfg.port}"#`http://''${location.hostname||"127.0.0.1"}:${toString cfg.port}`#g' {} +
    staticAfter=$(grep -rhoF '"http://127.0.0.1:${toString cfg.port}"' "$out" --include='*.js' | wc -l || true)
    if [ "$staticAfter" -ne 0 ]; then
      echo "sub-store-frontend: $staticAfter quoted code defaults left after dynamic patch" >&2
      exit 1
    fi
    dynCount=$(grep -rhoF 'location.hostname' "$out" --include='*.js' | wc -l || true)
    if [ "$dynCount" -ne "$staticBefore" ]; then
      echo "sub-store-frontend: dynamic defaults $dynCount != expected $staticBefore" >&2
      exit 1
    fi
    # 3) touch sw.js: a byte-different service worker makes browsers re-precache
    #    on the next visit even though the hashed chunk filenames did not change.
    printf '\n// nix-patch: %s location.hostname backend\n' "${frontendVersion}" >> "$out/sw.js"
  '';
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
      // lib.optionalAttrs cfg.frontend.enable {
        # Static panel assets; the backend starts its frontend server for them on a
        # separate port (API and panel stay independent, UI calls the API by URL).
        SUB_STORE_FRONTEND_PATH = frontendDist;
        SUB_STORE_FRONTEND_HOST = cfg.host;
        SUB_STORE_FRONTEND_PORT = toString cfg.frontend.port;
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
