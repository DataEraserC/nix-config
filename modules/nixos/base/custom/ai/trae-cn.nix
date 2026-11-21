# ===============================================================================
#
# Trae CN - ByteDance's AI-native IDE, China edition.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# trae-cn) together with its update script; this file only wires it up.
# nur-DataEraserC exports no nixosModule for it, so the enable option below is
# the only switch (there is no upstream module to import).
#
# State lives in ~/.trae-cn (extension storage; the app's `dataFolderName`) and
# ~/.config/Trae CN/User (app user data, rules, MCP configs, sessions). On a
# tmpfs root, modules.agent-accounts preserves both.
#
# Check
#   trae-cn --version   # VS Code base version, not the Trae build number
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
