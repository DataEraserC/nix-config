# ===============================================================================
#
# CodeBuddy - Tencent's terminal AI coding assistant (unfree vendor binary).
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# codebuddy) together with its update script; this file only wires it up.
#
# `package` exists so a host can swap in `codebuddy-acp`, the NUR proxy that
# installs itself as `bin/codebuddy` (same name, so every launch config and
# shell alias keeps working) and answers the ACP `session/list` method the
# vendor binary lacks. WebMux needs that method to recognise an agent session,
# so a host that wants CodeBuddy in the chat view sets
# `modules.codebuddy.package` and declares the agent in
# `modules.webmux.acpAgents.codebuddy`.
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
        binary; point it at `codebuddy-acp` to get ACP `session/list` support
        (and with it the WebMux chat view) at the cost of one proxy process per
        invocation.
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
