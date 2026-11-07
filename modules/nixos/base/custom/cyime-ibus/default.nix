# Register the CyIME engine with IBus at build time.
#
# The nixpkgs `ibus-daemon` wrapper pins `IBUS_COMPONENT_PATH` to the
# `ibus-with-plugins` store path, so component XML shipped anywhere else (for
# example via `home.sessionVariables`) is never scanned and the engine stays
# invisible to `ibus list-engine`. Adding the package to
# `i18n.inputMethod.ibus.engines` merges its component XML into that pinned
# directory when ibus-with-plugins is built.
#
# Only the GNOME Wayland variant of idols-ai runs CyIME (see that host's
# `modules.cyime-ibus.enable`), the niri and KDE variants keep fcitx5.
{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.cyime-ibus;
in
{
  options.modules.cyime-ibus = {
    enable = lib.mkEnableOption "register the CyIME engine with IBus";
  };

  config = lib.mkIf cfg.enable {
    i18n.inputMethod.ibus.engines = [ nur-DataEraserC.packages.${pkgs.system}.cyime ];
  };
}
