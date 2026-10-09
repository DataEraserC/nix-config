# ===============================================================================
#
# open-webui - self-hosted web UI for LLMs (ChatGPT-style chat), fronting ollama
# and the OpenAI-compatible gateways on the same host (new-api 1100,
# opencode2api 1101/1102, mimocode2api 1103, m365-copilot2api 1104,
# cliproxyapi 1105, omniroute 1106).
#
# Uniform wrapper shared by every host, same pattern as new-api.nix: hosts only
# toggle `modules.open-webui.enable` and set `modules.open-webui.port` (taken
# from the port registry, myvars.networking.services.open-webui.hosts.<machine>.port),
# while the remaining service settings (package, bind address) live here so the
# hosts stay byte-identical. The port is only read under `enable`, so a host that
# does not run the unit never forces it.
#
# Binds to 0.0.0.0:1107 by default - the next free port of the 1100 service series.
# Currently disabled on every host (modules.open-webui.enable = false); wsl-work
# runs no copy at all and reaches idols-ai through the `openwebui` port-forward
# tunnel (local 31107 -> remote 1107), kept for a future re-enable.
#
# Mutable state lives in /var/lib/open-webui (the NixOS module default); the
# legacy ~/.config/open-webui entry kept in preservation.nix only preserves
# pre-migration data.
#
# Check Service Status
#   systemctl status open-webui
# Check logs
#   journalctl -u open-webui --since "2 minutes ago"
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.open-webui;
in
{
  options.modules.open-webui = {
    enable = lib.mkEnableOption "Open WebUI chat frontend for the local LLM gateways";
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port open-webui listens on; the host that uses this module must set it (port registry myvars.networking.services.open-webui.hosts.<machine>.port).";
    };
  };

  # Package and bind address apply on every host so the binding is identical
  # whether or not the unit runs here; enable and port (set by the host from
  # the port registry) are gated by enable, since cfg.port has no default.
  config = lib.mkMerge [
    {
      services.open-webui = {
        # mkDefault: one uniform package choice (primary nixpkgs) that a host can
        # still override plainly via services.open-webui.package if needed.
        package = lib.mkDefault pkgs.open-webui;
        host = "0.0.0.0";
      };
    }
    (lib.mkIf cfg.enable {
      services.open-webui = {
        enable = true;
        port = cfg.port;
      };
    })
  ];
}
