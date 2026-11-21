# ===============================================================================
#
# Qoder CN CLI - Alibaba's terminal agent client, China edition.
#
# The international edition is the sibling module `qodercli`. Both modules just
# expose a package: the two upstream binaries are separate builds with separate
# release manifests, so each gets its own NUR derivation
# (pkgs/uncategorized-DataEraserC/qoderclicn).
#
# The CN build is the same code with a different brand: the user config root is
# ~/.qoder-cn instead of ~/.qoder, which is what keeps a CN account out of the
# international one. `modules.agent-accounts` preserves that directory, and the
# ACP handshake reports `qoder-cli-cn`, the name WebMux recognises.
#
# Check
#   qoderclicn --version
#   qoderclicn login
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.qoderclicn;
in
{
  options.modules.qoderclicn = {
    enable = lib.mkEnableOption "the Qoder CN CLI, Alibaba's terminal agent client (China edition)";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = nur-DataEraserC.legacyPackages.${pkgs.stdenv.hostPlatform.system}.qoderclicn or null;
      description = ''
        Package providing the `qoderclicn` executable. Defaults to the release
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
        message = "modules.qoderclicn.package must be set when the module is enabled (the DataEraserC NUR is not providing `qoderclicn`).";
      }
    ];
  };
}
