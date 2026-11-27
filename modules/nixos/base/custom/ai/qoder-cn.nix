# ===============================================================================
#
# Qoder CN App - Alibaba's agent workbench for human and AI software teams,
# China edition.
#
# This is the Electron workbench, not the VS Code-based Qoder CN IDE. The
# derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# qoder-cn-wayland), which overrides the base qoder-cn with the
# Wayland/waypipe ready-to-show fallback; this file only wires it up.
#
# State lives in ~/.qoder-cn (agent binaries, plugins, bundled resources) and
# ~/.config/com.qodercn.app.stable (Electron user data: login, sessions,
# settings). On a tmpfs root, modules.agent-accounts preserves both.
#
# Check
#   command -v qoder-cn   # GUI app, there is no --version CLI
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.qoder-cn;
in
{
  options.modules.qoder-cn = {
    enable = lib.mkEnableOption "Qoder CN App, Alibaba's agent workbench (China edition)";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.qoder-cn-wayland or null;
      description = ''
        Package providing the `qoder-cn` executable. Defaults to the
        Wayland/waypipe variant from the DataEraserC NUR; a host may override
        it to pin the unpatched build.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optional (cfg.package != null) cfg.package;

    assertions = [
      {
        assertion = cfg.package != null;
        message = "modules.qoder-cn.package must be set when the module is enabled (the DataEraserC NUR is not providing `qoder-cn-wayland`).";
      }
    ];
  };
}
