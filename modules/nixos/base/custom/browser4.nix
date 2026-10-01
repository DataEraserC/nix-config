# ===============================================================================
#
# Browser4 - MCP-driven browser automation: Rust CLI (browser4-cli) driving a
# prebuilt Java/Spring backend bundle via HTTP MCP on 127.0.0.1:8182.
#
# This wrapper uses the DataEraserC NUR module, which provides
# `programs.dataEraserc.browser4`. It only puts the CLI on PATH (the packaged
# wrapper supplies the store runtime, creates the log directory and warns on
# a BROWSER4_RUNTIME_DIR override) and wires an optional browser path.
#
# The backend is deliberately NOT a systemd service; `browser4-cli` has no
# start/serve subcommand and re-spawns the backend on demand. Under the dsh
# harness, run long-lived backend work in a harness background job instead —
# recipe in pkgs/uncategorized/browser4/AGENTS.md of the nur-packages repo.
#
# Set browserPath to the Chrome/Chromium binary to drive on NixOS (nothing on
# PATH matches by default); it is exported as BROWSER4_BROWSER_PATH.
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.browser4;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ nur-DataEraserC.nixosModules.browser4 ];

  options.modules.browser4 = {
    enable = lib.mkEnableOption "browser4 browser automation CLI";

    browserPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to the Chrome/Chromium binary browser4 drives, exported as BROWSER4_BROWSER_PATH; null leaves it unset.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.dataEraserc.browser4 = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.browser4;
      inherit (cfg) browserPath;
    };
  };
}
