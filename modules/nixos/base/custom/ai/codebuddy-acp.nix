# ===============================================================================
#
# CodeBuddy ACP - ACP proxy for Tencent's terminal AI coding assistant.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# codebuddy-acp). It installs only the `codebuddy-acp` command and transparently
# execs the vendor CLI for non-stdio-ACP invocations; the vendor `codebuddy` /
# `cbc` commands are not exposed by this module.
#
# The proxy keeps the vendor's state layout: ~/.codebuddy contains sessions,
# plugins, credentials and history, while ~/.local/share/CodeBuddyExtension
# holds auth shared with WorkBuddy. On a tmpfs root, modules.agent-accounts
# preserves both.
#
# Check
#   codebuddy-acp --version
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.codebuddy-acp;
in
{
  options.modules.codebuddy-acp = {
    enable = lib.mkEnableOption "the CodeBuddy ACP proxy for Tencent's terminal AI coding assistant";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = nur-DataEraserC.legacyPackages.${pkgs.stdenv.hostPlatform.system}.codebuddy-acp or null;
      description = ''
        Package providing the `codebuddy-acp` executable. Defaults to the ACP
        proxy from the DataEraserC NUR; a host may override it to pin a
        different build.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optional (cfg.package != null) cfg.package;

    assertions = [
      {
        assertion = cfg.package != null;
        message = "modules.codebuddy-acp.package must be set when the module is enabled (the DataEraserC NUR is not providing `codebuddy-acp`).";
      }
    ];
  };
}
