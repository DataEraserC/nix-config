{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.desktop.cyime;
  cfgIce = config.modules.cyime-ice;

  stateDir = "${config.home.homeDirectory}/.local/share/cyime-linux";

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

  # `cyime-setup --ice-dir` only rewrites the schema when it is absent, so the
  # activation below backs up the old schema before preparing rime-ice and
  # stamps the store path to stay idempotent across switches.
  options.modules.cyime-ice = {
    enable = lib.mkEnableOption "rime-ice (雾凇拼音) tables for CyIME";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.rime-ice;
      description = "rime-ice data source providing rime_ice.dict.yaml";
    };
  };

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

    # Rime only deploys the schema the engine selected; running the setup
    # script alone leaves the old compiled snapshot in place. The activation
    # below writes the tables, drops the stale `build/` cache and restarts the
    # GNOME IBus unit so the next engine start compiles the new schema.
    #
    # Idempotency: the store path of the rime-ice data source is stamped into
    # the state directory. A second switch with the same package does nothing,
    # which keeps the accumulated `*.userdb` files intact. Note that
    # `cyime-setup` only copies dictionary tables that are missing, so a
    # rime-ice *upgrade* keeps the previously copied `*.dict.yaml` files.
    home.activation.cyime-ice = lib.mkIf cfgIce.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ice="${cfgIce.package}"
        rime="${stateDir}/rime"
        stamp="${stateDir}/.rime-ice-store-path"
        schema="$rime/cyime_pinyin.schema.yaml"

        if [ "$(cat "$stamp" 2>/dev/null)" != "$ice" ]; then
          mkdir -p "$rime"
          backup="$schema.backup-$(date +%Y%m%d%H%M%S)"

          # `--ice-dir` only rewrites cyime_pinyin.schema.yaml when it is
          # absent, so an existing schema would silently keep pinyin_simp.
          if [ -f "$schema" ]; then
            mv "$schema" "$backup"
          fi

          # `--user-dir` is passed explicitly so the tables land in `$rime`
          # even when XDG_DATA_HOME differs from the default lookup.
          if ${cyime}/bin/cyime-setup --user-dir "$rime" --ice-dir "$ice/share/rime-data"; then
            # `build/` is Rime's compiled cache; moving it (instead of
            # deleting it) forces a rebuild from the new tables. Only reached
            # when the schema really changed.
            if [ -d "$rime/build" ]; then
              mv "$rime/build" "$rime/build.backup-$(date +%Y%m%d%H%M%S)"
            fi
            rm -f "$backup"
            echo "$ice" > "$stamp"
            systemctl --user try-restart \
              org.freedesktop.IBus.session.GNOME.service 2>/dev/null || true
          else
            # Keep the previous schema usable; the next switch retries.
            if [ -f "$backup" ]; then
              mv "$backup" "$schema"
            fi
            echo "cyime: rime-ice preparation failed; the next switch retries" >&2
          fi
        fi
      ''
    );
  };
}
