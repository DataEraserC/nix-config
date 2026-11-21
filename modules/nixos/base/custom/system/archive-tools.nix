{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.archive-tools = {
    enable = lib.mkEnableOption "RAR archive support (rar/unrar CLI tools)";
  };

  config = lib.mkIf config.modules.archive-tools.enable {
    # rar/unrar are unfree, so they cannot live in the shared base package
    # list that every host inherits; hosts that actually open RAR archives
    # opt in here. `unzipNLS`/`p7zip` (modules/base/packages.nix) already
    # cover the free formats and link libnatspec for filename charset
    # conversion, so the library itself needs no top-level entry.
    environment.systemPackages = with pkgs; [
      rar
      unrar
    ];
  };
}
