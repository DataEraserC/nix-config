# ===============================================================================
#
# WorkBuddy - Tencent's AI agent desktop app (unfree vendor binary, Electron).
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# workbuddy) together with its update script; this file only wires it up. It is
# a ~1.6 GiB unpacked desktop application, so it pulls in a GTK stack.
#
# State lives in ~/.workbuddy (database, settings, session cookies, plugins,
# bundled node/python runtimes) and ~/.local/share/CodeBuddyExtension (auth
# shared with codebuddy); hosts with a tmpfs root carry both across boots from
# their own preservation file. ~/.sheetagent holds logs only and ~/WorkBuddy is
# an empty scaffold, so neither is preserved.
#
# Check
#   workbuddy --version
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.workbuddy;
in
{
  options.modules.workbuddy.enable = lib.mkEnableOption "WorkBuddy, Tencent's AI agent desktop app";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.workbuddy
    ];
  };
}
