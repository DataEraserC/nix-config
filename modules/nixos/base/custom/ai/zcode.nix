# ===============================================================================
#
# ZCode - Z.ai's AI coding workspace.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# zcode) together with its update script; this file only wires it up.
# nur-DataEraserC exports no nixosModule for it, so the enable option below is
# the only switch (there is no upstream module to import).
#
# The CN and international editions are the same AppImage (same URL, hash,
# productName, state directories and single-instance lock); the region is
# chosen by the account you log in with, so one package serves both.
#
# State lives in ~/.zcode (CLI sessions, wiki, agent runtimes) and
# ~/.config/ZCode (Electron user data: login, rules, MCP configs, sessions).
# On a tmpfs root, modules.agent-accounts preserves both.
#
# Check
#   command -v zcode   # GUI app, there is no --version CLI
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.zcode;
in
{
  options.modules.zcode.enable = lib.mkEnableOption "ZCode, Z.ai's AI coding workspace";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.zcode
    ];
  };
}
