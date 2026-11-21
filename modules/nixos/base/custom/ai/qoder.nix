# ===============================================================================
#
# Qoder App - Alibaba's agent workbench for human and AI software teams,
# international edition.
#
# This is the Electron workbench, not the VS Code-based Qoder IDE. The
# derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/qoder)
# together with its update script; this file only wires it up.
#
# State lives in ~/.qoder (agent binaries, plugins, bundled resources) and
# ~/.config/com.qoder.app.stable (Electron user data: login, sessions,
# settings). On a tmpfs root, modules.agent-accounts preserves both.
#
# Check
#   command -v qoder   # GUI app, there is no --version CLI
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.qoder;
in
{
  options.modules.qoder.enable = lib.mkEnableOption "Qoder App, Alibaba's agent workbench (international edition)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.qoder
    ];
  };
}
