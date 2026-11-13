# ===============================================================================
#
# Raccoon Work - SenseTime's AI office assistant desktop client.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# xiaohuanxiong) together with its update script; this file only wires it up.
# nur-DataEraserC exports no nixosModule for it, so the enable option below is
# the only switch (there is no upstream module to import).
#
# The enable option installs the app for the single, global instance: it uses
# the profile at ~/.config/office-raccoon and the workspace at ~/RaccoonWork.
# Additional isolated accounts come from modules.agent-accounts (the app is in
# its table as `xiaohuanxiong`); see modules/nixos/base/custom/ai/
# agent-accounts.nix.
#
# Check
#   command -v xiaohuanxiong   # GUI app, there is no --version CLI
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.xiaohuanxiong;
in
{
  options.modules.xiaohuanxiong.enable = lib.mkEnableOption "Raccoon Work, SenseTime's AI office assistant desktop client";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.xiaohuanxiong
    ];
  };
}
