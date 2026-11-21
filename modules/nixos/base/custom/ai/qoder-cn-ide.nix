# ===============================================================================
#
# Qoder CN IDE - Alibaba's agentic coding IDE, China edition.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# qoder-cn) together with its update script; this file only wires it up.
# nur-DataEraserC exports no nixosModule for it, so the enable option below is
# the only switch (there is no upstream module to import).
#
# State lives in ~/.qoder-cn-ide (dataFolderName: canvas resources, plugins, CLI
# sessions) and ~/.config/QoderCN (Electron user data: login, settings, rules,
# MCP configs, sessions). On a tmpfs root, modules.agent-accounts preserves both.
#
# Check
#   command -v qoder-cn   # GUI app, there is no --version CLI
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.qoder-cn-ide;
in
{
  options.modules.qoder-cn-ide.enable = lib.mkEnableOption "Qoder CN IDE, Alibaba's agentic coding IDE (China edition)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.qoder-cn-ide
    ];
  };
}
