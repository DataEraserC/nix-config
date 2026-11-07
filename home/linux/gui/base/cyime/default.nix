{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.desktop.cyime;

  # TODO(CyIME): set this to the published nur-DataEraserC attribute.
  # The packaging work currently lands as either `cyime` or `cyime-linux`; when
  # the name is confirmed, change only this line. It is not evaluated while
  # `modules.desktop.cyime.enable` is false, so the default configuration keeps
  # evaluating even before the package exists.
  cyime = nur-DataEraserC.packages.${pkgs.system}.cyime;

  # The package is expected to install its IBus component XML here. The second
  # entry is the runtime location used by `setup_ibus.py --register`; the last
  # one is the NixOS system profile.
  ibusComponentPath = lib.concatStringsSep ":" [
    "${cyime}/share/ibus/component"
    "${config.home.homeDirectory}/.local/share/ibus/component"
    "/run/current-system/sw/share/ibus/component"
  ];
in
{
  options.modules.desktop.cyime.enable =
    lib.mkEnableOption "CyIME IBus/Rime frontend instead of Fcitx5";

  config = lib.mkIf cfg.enable {
    # CyIME Linux is an IBus engine (`cyime-rime`), not a Fcitx5 addon. Force
    # Home Manager's Fcitx5 wiring (daemon, addon packages and session
    # variables) off; the `fcitx5.addons` lists in `home/base/gui/rime` and
    # `home/linux/gui/base/vinput` then stay inert.
    i18n.inputMethod.enable = lib.mkForce false;
    i18n.inputMethod.type = lib.mkForce null;

    # Vinput is an Fcitx5 addon daemon and has no engine to talk to here.
    modules.desktop.vinput.enable = lib.mkForce false;

    home.packages = [
      cyime
      pkgs.ibus
    ];

    # IBus is the framework GNOME already uses. These variables are only
    # applied to a new login session; they mirror the system-wide ibus values
    # on the GNOME host and make the same choice explicit on niri/KDE.
    #
    # No ibus-daemon service is declared on purpose: `pkgs.ibus` ships the
    # `org.freedesktop.IBus` D-Bus service plus
    # `org.freedesktop.IBus.session.generic.service`, which systemd starts on
    # demand in non-GNOME sessions. GNOME Shell uses its own
    # `org.freedesktop.IBus.session.GNOME` unit instead.
    home.sessionVariables = {
      GTK_IM_MODULE = "ibus";
      QT_IM_MODULE = "ibus";
      XMODIFIERS = "@im=ibus";
      GLFW_IM_MODULE = "ibus";
      IBUS_COMPONENT_PATH = ibusComponentPath;
    };

    # GNOME reads input sources from here; keep the US layout first and add
    # the CyIME engine. On KDE the equivalent choice is made in System
    # Settings, and niri has no input-source list.
    dconf.settings = lib.mkIf config.modules.desktop.gnome-wayland.enable {
      "org/gnome/desktop/input-sources".sources = [
        (lib.gvariant.mkTuple [
          "xkb"
          "us"
        ])
        (lib.gvariant.mkTuple [
          "ibus"
          "cyime-rime"
        ])
      ];
    };
  };
}
