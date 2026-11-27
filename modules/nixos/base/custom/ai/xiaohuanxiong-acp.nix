# ===============================================================================
#
# Raccoon Work ACP - ACP bridge and Martty TUI for SenseTime's Raccoon agent.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# xiaohuanxiong-acp). It installs the `xiaohuanxiong-acp` command and the
# `xiaohuanxiong-acp-resume` symlink; the vendor Box-Agent runtime and Martty
# are injected at build time, so no desktop GUI or Electron app is involved.
#
# The bridge keeps its own agent home under ~/.box-agent in the instance HOME.
# modules.agent-accounts gives each `multi-instance xiaohuanxiong-acp N`
# account its own copy, independent of the desktop `xiaohuanxiong` app's
# ~/.box-agent (a different stateDirectoryKey).
#
# Check
#   xiaohuanxiong-acp --version
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.xiaohuanxiong-acp;
in
{
  options.modules.xiaohuanxiong-acp = {
    enable = lib.mkEnableOption "the ACP bridge and terminal client for the Raccoon Work agent";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default =
        nur-DataEraserC.legacyPackages.${pkgs.stdenv.hostPlatform.system}.xiaohuanxiong-acp or null;
      description = ''
        Package providing the `xiaohuanxiong-acp` executable. Defaults to the
        ACP bridge from the DataEraserC NUR; a host may override it to pin a
        different build.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optional (cfg.package != null) cfg.package;

    assertions = [
      {
        assertion = cfg.package != null;
        message = "modules.xiaohuanxiong-acp.package must be set when the module is enabled (the DataEraserC NUR is not providing `xiaohuanxiong-acp`).";
      }
    ];
  };
}
