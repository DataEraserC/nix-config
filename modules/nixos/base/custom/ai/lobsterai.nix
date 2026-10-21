# ===============================================================================
#
# LobsterAI - NetEase Youdao's open-source desktop-grade AI agent.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# lobsterai-wrapper, which wraps lobsterai-unwrapped) but has no update script,
# so its version tag is bumped by hand; this file only wires it up.
# nur-DataEraserC exports no nixosModule for it, so the enable option below is
# the only switch (there is no upstream module to import).
#
# State lives in ~/.config/LobsterAI (Electron userData: lobsterai.sqlite with
# sessions, SKILLs, dsh/ and openclaw/ runtimes, logs) and ~/lobsterai/project
# (default working directory, created at startup). Hosts with a tmpfs root
# should carry both across boots from their own preservation file.
#
# Check
#   command -v lobsterai   # GUI app, there is no --version CLI
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
