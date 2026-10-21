# ===============================================================================
#
# Trae International - ByteDance's AI-native IDE, global edition.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# trae-intl) together with its update script; this file only wires it up.
#
# State lives in ~/.trae (CLI config, sessions) and
# ~/.config/Trae/User (app user data, rules, MCP configs).
# Hosts with a tmpfs root should carry both across boots from their own
# preservation file.
#
# Check
#   trae --version
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.trae-intl;
in
{
  options.modules.trae-intl.enable = lib.mkEnableOption "Trae International, ByteDance's AI-native IDE (global edition)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.trae-intl
    ];
  };
}
