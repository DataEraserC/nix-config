# ===============================================================================
#
# workbuddy2api - multi-provider gateway (WorkBuddy / Qoder / Trae / MiniMax /
# Doubao / CodeArts) exposing an OpenAI-compatible API plus a management panel
# on the same port.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.workbuddy2api`.
#
# Binds 0.0.0.0:1111 like the sibling gateways; openFirewall stays off so the
# port is reachable only over the VPN overlays and the LAN posture is unchanged.
# Upstream has no TLS, so keep it behind an authenticated reverse proxy when
# reaching it from an untrusted network.
#
# The gateway API key is maintained in agenix
# (secrets/agenix/workbuddy2api-api-key.age, one shared key for every host
# that enables this module) and decrypted to /run/agenix/workbuddy2api-api-key
# (0600, owned by the service account); read it with
#   sudo cat /run/agenix/workbuddy2api-api-key
# The NUR module loads it as a systemd credential and exports WB2A_API_KEY, so
# auto-generation into ${stateDir}/api-key is skipped. Rotate with
#   just -f secrets/Justfile edit agenix/workbuddy2api-api-key.age   (sudo)
# followed by a service restart - the env-passed key is fixed at process start.
#
# Mutable state lives in /var/lib/workbuddy2api: config.json (seeded once, then
# owned by the panel), auths/ (WorkBuddy account files), data/ (state, usage,
# IDE account pools, request-logs) and trae/ (Trae check-in state). Account
# enrollment is done in the panel, so a redeploy keeps every account.
#
# Check Service Status
#   systemctl status workbuddy2api
# Check logs
#   journalctl -u workbuddy2api --since "2 minutes ago"
# Probe the gateway (zero accounts answers 503 with total:0, which is expected)
#   curl http://127.0.0.1:1111/healthz
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.workbuddy2api;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ nur-DataEraserC.nixosModules.workbuddy2api ];

  options.modules.workbuddy2api = {
    enable = lib.mkEnableOption "WorkBuddy2API multi-provider gateway and panel";
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port workbuddy2api listens on for both the API and the panel; the host that uses this module must set it (port registry myvars.networking.services.workbuddy2api.hosts.<machine>.port).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.workbuddy2api = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.workbuddy2api-panel;
      listenAddress = "0.0.0.0";
      port = cfg.port;
      openFirewall = false;
      # agenix-managed key, loaded via systemd LoadCredential (agent2api style).
      apiKeyFile = "/run/agenix/workbuddy2api-api-key";
    };
  };
}
