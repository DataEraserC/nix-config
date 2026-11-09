# ===============================================================================
#
# CodeBuddy - Tencent's terminal AI coding assistant (unfree vendor binary).
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# codebuddy) together with its update script; this file only wires it up.
#
# `package` is overridable so a host can pin a different build without editing
# this module; it defaults to the vendor binary from the NUR.
#
# State lives in ~/.codebuddy (sessions, plugins, credentials, history) and
# ~/.local/share/CodeBuddyExtension (auth shared with workbuddy); on a tmpfs
# root, modules.agent-accounts preserves both.
#
# Check
#   codebuddy --version
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.codebuddy;
in
{
  options.modules.codebuddy = {
    enable = lib.mkEnableOption "CodeBuddy, Tencent's terminal AI coding assistant";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.codebuddy;
      description = ''
        Package providing the `codebuddy` executable. Defaults to the vendor
        binary from the DataEraserC NUR; a host may override it to pin a
        different build.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    assertions = [
      {
        assertion = cfg.package != null;
        message = "modules.codebuddy.package must be set when the module is enabled (the DataEraserC NUR is not providing `codebuddy`).";
      }
    ];
  };
}
