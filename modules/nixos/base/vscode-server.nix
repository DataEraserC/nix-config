{
  config,
  lib,
  vscode-server,
  ...
}:
{
  imports = [ vscode-server.nixosModules.default ];

  options.modules.vscode-server = {
    enable = lib.mkEnableOption "NixOS vs-code server";
  };

  config = lib.mkIf config.modules.vscode-server.enable {
    services.vscode-server.enable = true;
  };
}
