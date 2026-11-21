# ===============================================================================
#
# Qoder CLI - Alibaba's terminal agent client, international edition.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# qodercli): the upstream Bun single-file binary, pinned through the release
# manifest the CLI itself polls. The China edition is the sibling module
# `qoderclicn`.
#
# The CLI keeps everything - the login, the sessions under ~/.qoder/projects,
# settings, skills and plugins - below ~/.qoder, so one bind mount over that
# directory gives each account its own identity. On a tmpfs root,
# modules.agent-accounts preserves it.
#
# `--acp` serves the Agent Client Protocol on stdio, which is how WebMux drives
# the CLI; the per-account bindings live in modules.webmux.acpAgents.
# `qodercli update` has no use here - the store holds the only copy of the
# binary, so upgrades come from the NUR input.
#
# Check
#   qodercli --version
#   qodercli login
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.qodercli;
in
{
  options.modules.qodercli = {
    enable = lib.mkEnableOption "the Qoder CLI, Alibaba's terminal agent client (international edition)";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = nur-DataEraserC.legacyPackages.${pkgs.stdenv.hostPlatform.system}.qodercli or null;
      description = ''
        Package providing the `qodercli` executable. Defaults to the release
        manifest build from the DataEraserC NUR; a host may override it to pin a
        different build.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optional (cfg.package != null) cfg.package;

    assertions = [
      {
        assertion = cfg.package != null;
        message = "modules.qodercli.package must be set when the module is enabled (the DataEraserC NUR is not providing `qodercli`).";
      }
    ];
  };
}
