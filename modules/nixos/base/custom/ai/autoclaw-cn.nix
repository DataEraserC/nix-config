# ===============================================================================
#
# AutoClaw CN - Zhipu AI's general AI agent desktop app (China edition).
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# autoclaw-cn) together with its update script; this file only wires it up.
# nur-DataEraserC exports no nixosModule for it, so the enable option below is
# the only switch (there is no upstream module to import).
#
# The launcher pins XDG_CONFIG_HOME to ~/.config/autoclaw-cn, so the app keeps
# its Electron profile in ~/.config/autoclaw-cn/AutoClaw and
# ~/.config/autoclaw-cn/AutoClaw-official. On a tmpfs root,
# modules.agent-accounts preserves that directory.
#
# Check
#   command -v autoclaw-cn   # GUI app, there is no --version CLI
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.autoclaw-cn;
in
{
  options.modules.autoclaw-cn.enable = lib.mkEnableOption "AutoClaw CN, Zhipu AI's general AI agent desktop app (China edition)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.autoclaw-cn
    ];
  };
}
