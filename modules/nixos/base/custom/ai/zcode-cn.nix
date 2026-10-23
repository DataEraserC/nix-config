# ===============================================================================
#
# ZCode CN - Z.ai's AI coding workspace, China edition.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# zcode-cn) together with its update script; this file only wires it up.
# nur-DataEraserC exports no nixosModule for it, so the enable option below is
# the only switch (there is no upstream module to import).
#
# State lives in ~/.zcode (CLI sessions, wiki, agent runtimes) and
# ~/.config/ZCode (Electron user data: login, rules, MCP configs, sessions).
# On a tmpfs root, modules.agent-accounts preserves both.
#
# Check
#   command -v zcode-cn   # GUI app, there is no --version CLI
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.zcode-cn;
in
{
  options.modules.zcode-cn.enable = lib.mkEnableOption "ZCode CN, Z.ai's AI coding workspace (China edition)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.zcode-cn
    ];
  };
}
