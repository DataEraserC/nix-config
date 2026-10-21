# ===============================================================================
#
# Trae CN - ByteDance's AI-native IDE, China edition.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# trae-cn) together with its update script; this file only wires it up.
#
# State lives in ~/.trae-cn (CLI config, sessions) and
# ~/.config/Trae CN/User (app user data, rules, MCP configs).
# Hosts with a tmpfs root should carry both across boots from their own
# preservation file.
#
# Check
#   trae_cn --version
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.trae-cn;
in
{
  options.modules.trae-cn.enable = lib.mkEnableOption "Trae CN, ByteDance's AI-native IDE (China edition)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.trae-cn
    ];
  };
}
