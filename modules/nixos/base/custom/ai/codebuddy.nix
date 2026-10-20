# ===============================================================================
#
# CodeBuddy - Tencent's terminal AI coding assistant (unfree vendor binary).
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# codebuddy) together with its update script; this file only wires it up.
#
# State lives in ~/.codebuddy (sessions, plugins, credentials, history) and
# ~/.local/share/CodeBuddyExtension (auth shared with workbuddy); hosts with a
# tmpfs root carry both across boots from their own preservation file.
#
# Check
#   codebuddy --version
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.codebuddy;
in
{
  options.modules.codebuddy.enable = lib.mkEnableOption "CodeBuddy, Tencent's terminal AI coding assistant";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.codebuddy
    ];
  };
}
