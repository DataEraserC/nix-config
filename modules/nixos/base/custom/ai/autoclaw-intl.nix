# ===============================================================================
#
# AutoClaw International - Z.ai's general AI agent desktop app.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# autoclaw-intl) together with its update script; this file only wires it up.
# nur-DataEraserC exports no nixosModule for it, so the enable option below is
# the only switch (there is no upstream module to import).
#
# The launcher pins XDG_CONFIG_HOME to ~/.config/autoclaw-intl, so the app
# keeps its Electron profile in ~/.config/autoclaw-intl/AutoClaw and
# ~/.config/autoclaw-intl/AutoClaw-oversea-official. On a tmpfs root,
# modules.agent-accounts preserves that directory.
#
# Check
#   command -v autoclaw-intl   # GUI app, there is no --version CLI
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.autoclaw-intl;
in
{
  options.modules.autoclaw-intl.enable = lib.mkEnableOption "AutoClaw International, Z.ai's general AI agent desktop app";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.autoclaw-intl
    ];
  };
}
