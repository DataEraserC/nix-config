# ===============================================================================
#
# Trae International - ByteDance's AI-native IDE, global edition.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# trae-intl) together with its update script; this file only wires it up.
# nur-DataEraserC exports no nixosModule for it, so the enable option below is
# the only switch (there is no upstream module to import).
#
# State lives in ~/.trae (extension storage; the app's `dataFolderName`) and
# ~/.config/Trae/User (app user data, rules, MCP configs, sessions). On a tmpfs
# root, modules.agent-accounts preserves both.
#
# Check
#   trae --version   # VS Code base version, not the Trae build number
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
