# ===============================================================================
#
# LobsterAI - NetEase Youdao's open-source desktop-grade AI agent.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# lobsterai) together with its update script; this file only wires it up.
#
# State lives in ~/.config/lobsterai and ~/.local/share/lobsterai (sessions,
# skills, MCP configs, credentials, SQLite databases). Hosts with a tmpfs root
# should carry both across boots from their own preservation file.
#
# Check
#   lobsterai --version
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.lobsterai;
in
{
  options.modules.lobsterai.enable = lib.mkEnableOption "LobsterAI, NetEase Youdao's desktop-grade AI agent";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.lobsterai-wrapper
    ];
  };
}
