# ===============================================================================
#
# WorkBuddy International - Tencent's AI agent desktop app, global deployment.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# workbuddy-ai) together with its update script; this file only wires it up. It
# reuses the CN deb, so it is the same ~1.6 GiB Electron application and pulls in
# the same GTK stack. nur-DataEraserC exports no nixosModule for it, so the enable
# option below is the only switch.
#
# State lives in ~/.workbuddy-ai (its `dataFolderName`: database, settings,
# session cookies, plugins, bundled node/python runtimes), plus ~/.workbuddy for
# the device id and startup logs and ~/.local/share/CodeBuddyExtension for auth.
# On a tmpfs root, modules.agent-accounts preserves those three.
#
# Check
#   workbuddy-ai --version
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.workbuddy-ai;
in
{
  options.modules.workbuddy-ai.enable = lib.mkEnableOption "WorkBuddy International, Tencent's AI agent desktop app (global deployment)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.workbuddy-ai
    ];
  };
}
