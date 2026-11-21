# ===============================================================================
#
# MobileClaw - China Mobile Cloud's desktop AI office agent (unfree vendor
# binary, Electron).
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# mobileclaw) together with its update script; this file only wires it up.
#
# The vendor serves the package only behind a short-lived SigV4 URL, so the
# package pins the stable manager endpoint that redirects to one, plus the hash.
#
# State lives in three places, all of them hardcoded under $HOME:
#   ~/.config/com.cmss.mobileclaw-desktop  config, device ID, auth token
#   ~/.config/MobileClaw                   Electron userData (holds the lock)
#   ~/Documents/MobileClaw                 default agent workspace
# modules.agent-accounts gives each account its own copy of all three.
#
# Check
#   mobileclaw   (starts the app; there is no --version)
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.mobileclaw;
in
{
  options.modules.mobileclaw.enable = lib.mkEnableOption "MobileClaw, China Mobile Cloud's desktop AI office agent";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.mobileclaw
    ];
  };
}
