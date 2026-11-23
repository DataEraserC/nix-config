{
  config,
  lib,
  pkgs-master,
  ...
}:
let
  cfg = config.modules.vscode;
in
{
  options.modules.vscode = {
    enable = lib.mkEnableOption "Visual Studio Code desktop editor";

    package = lib.mkPackageOption pkgs-master "vscode" { };

    passwordStore = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "gnome-libsecret";
      description = "Electron password-store backend; null leaves VS Code's default unchanged.";
    };

    extraCommandLineArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional command-line arguments passed to the VS Code package wrapper.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      # Extensions and settings are managed by VS Code Settings Sync. The
      # writable state is preserved by the downstream host profile.
      enable = true;
      package = cfg.package.override {
        commandLineArgs =
          lib.optional (cfg.passwordStore != null) "--password-store=${cfg.passwordStore}"
          ++ cfg.extraCommandLineArgs;
      };
    };
  };
}
