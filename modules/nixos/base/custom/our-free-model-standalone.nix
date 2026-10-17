# ===============================================================================
#
# our-free-model-standalone - Our Free Model standalone free-model gateway.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `services.dataEraserc.our-free-model-standalone`.
#
# Binds to 127.0.0.1:18900 (loopback only - the upstream entry point rejects
# any other bind address), so reaching it from other machines means putting a
# reverse proxy in front. If the port is busy the gateway walks to the next
# free one and logs the port it actually took; check the management URL in the
# journal when the port does not respond.
#
# State lives in /var/lib/our-free-model-standalone (account pool, credentials,
# settings, API key); each host's preservation-downstream.nix carries it across
# boots.
#
# Check Service Status
#   systemctl status our-free-model-standalone
# Check logs
#   journalctl -u our-free-model-standalone --since "2 minutes ago"
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.our-free-model-standalone;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ nur-DataEraserC.nixosModules.our-free-model-standalone ];

  options.modules.our-free-model-standalone = {
    enable = lib.mkEnableOption "the Our Free Model standalone free-model gateway";
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port our-free-model-standalone listens on; the host that uses this module must set it (port registry myvars.networking.services.our-free-model-standalone.hosts.<machine>.port).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.dataEraserc.our-free-model-standalone = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.dsh-our-free-model-standalone;
      port = cfg.port;
    };
  };
}
