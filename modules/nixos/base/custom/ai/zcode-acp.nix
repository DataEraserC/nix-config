# ===============================================================================
#
# ZCode ACP - ACP bridge for Z.ai's terminal coding agent.
#
# The derivation lives in nur-DataEraserC (pkgs/uncategorized-DataEraserC/
# zcode-acp). It installs the `zcode-acp-server` and `zcode-acp` commands and
# injects the vendor CLI (the `zcode-cli` package's `zcode` wrapper, extracted
# from the desktop AppImage) via ZCODE_BIN; the vendor binary itself is not
# exposed by this module.
#
# The bridge keeps the vendor's state layout: ~/.zcode holds CLI sessions and
# credentials (the desktop app's login under ~/.zcode/v2 is reused). On a tmpfs
# root, modules.agent-accounts preserves it, and the `zcode-acp`/`zcode-cli`
# multi-instance apps each get their own copy per instance.
#
# Check
#   zcode-acp-server --version
# ===============================================================================
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.zcode-acp;
in
{
  options.modules.zcode-acp = {
    enable = lib.mkEnableOption "the ACP bridge for Z.ai's terminal coding agent";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = nur-DataEraserC.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zcode-acp or null;
      description = ''
        Package providing the `zcode-acp-server` executable. Defaults to the
        ACP bridge from the DataEraserC NUR; a host may override it to pin a
        different build.
      '';
    };

    vendorCli = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = nur-DataEraserC.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zcode-cli or null;
      description = ''
        Package providing the `zcode-cli` executable (the vendor CLI wrapper
        extracted from the desktop AppImage). Exposed on PATH because
        multi-instance resolves its executable with `command -v` and the
        terminal TUI is a documented direct form; the name is zcode-cli so it
        never shadows the desktop package's bin/zcode. The adapter itself
        reaches the vendor CLI through ZCODE_BIN, not through PATH.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      lib.optional (cfg.package != null) cfg.package
      ++ lib.optional (cfg.vendorCli != null) cfg.vendorCli;

    assertions = [
      {
        assertion = cfg.package != null;
        message = "modules.zcode-acp.package must be set when the module is enabled (the DataEraserC NUR is not providing `zcode-acp`).";
      }
    ];
  };
}
