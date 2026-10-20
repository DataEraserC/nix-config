# ===============================================================================
#
# CodeArts - Huawei Cloud's terminal coding agent (unfree vendor binary).
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# codearts) together with its update script; this file only wires it up.
#
# State lives in ~/.codeartsdoer (settings, opencode.db, permission storage,
# generative-ui); hosts with a tmpfs root carry it across boots from their own
# preservation file. ~/.codebase-cli is deliberately left out - it is a
# self-updating CLI cache the tool re-downloads on demand.
#
# Check
#   codearts --version
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.codearts;
in
{
  options.modules.codearts.enable = lib.mkEnableOption "CodeArts, Huawei Cloud's terminal coding agent";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.codearts
    ];
  };
}
