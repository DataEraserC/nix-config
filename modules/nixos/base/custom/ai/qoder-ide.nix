# ===============================================================================
#
# Qoder International - Alibaba's agentic coding IDE, global edition.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# qoder-intl) together with its update script; this file only wires it up.
# nur-DataEraserC exports no nixosModule for it, so the enable option below is
# the only switch (there is no upstream module to import).
#
# State lives in ~/.qoder (dataFolderName: canvas resources, plugins, CLI
# sessions) and ~/.config/Qoder (Electron user data: login, settings, rules,
# MCP configs, sessions). On a tmpfs root, modules.agent-accounts preserves both.
#
# Check
#   command -v qoder-intl   # GUI app, there is no --version CLI
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.qoder-intl;
in
{
  options.modules.qoder-intl.enable = lib.mkEnableOption "Qoder International, Alibaba's agentic coding IDE (global edition)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.qoder-intl
    ];
  };
}
