# ===============================================================================
#
# Qoder CN App - Alibaba's agent workbench for human and AI software teams,
# China edition.
#
# This is the Electron workbench, not the VS Code-based Qoder CN IDE. The
# derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/qoder-cn)
# together with its update script; this file only wires it up.
#
# State lives in ~/.qoder-cn (agent binaries, plugins, bundled resources) and
# ~/.config/com.qodercn.app.stable (Electron user data: login, sessions,
# settings). On a tmpfs root, modules.agent-accounts preserves both.
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
  cfg = config.modules.qoder-cn;
in
{
  options.modules.qoder-cn.enable = lib.mkEnableOption "Qoder CN App, Alibaba's agent workbench (China edition)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.qoder-cn
    ];
  };
}
