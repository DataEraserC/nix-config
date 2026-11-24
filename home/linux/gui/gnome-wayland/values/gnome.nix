{
  pkgs,
  lib,
  config,
  nur-ryan4yin,
  ...
}:
let
in
{
  home.packages = with pkgs.gnomeExtensions; [
    appindicator
    blur-my-shell
    gsconnect
    kimpanel
    clipboard-indicator
    mirror
    pkgs.qrencode # required by pkgs.gnomeExtensions.mirror

    # dconf-editor
    pkgs.dconf-editor
  ];
  dconf = {
    enable = true;
    settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      show-battery-percentage = true;
      clock-show-seconds = true;
    };
    settings."org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = with pkgs.gnomeExtensions; [
        appindicator.extensionUuid
        blur-my-shell.extensionUuid
        gsconnect.extensionUuid
        kimpanel.extensionUuid
        clipboard-indicator.extensionUuid
        mirror.extensionUuid
      ];
      # Dash favorites. Chrome's entry id comes from the nixpak wrapper, which
      # names it after the Flatpak appId; the bare `google-chrome.desktop` of the
      # unpackaged Chrome is gone, so GNOME silently drops that favorite.
      favorite-apps = [
        "com.mitchellh.ghostty.desktop"
        "com.google.Chrome.desktop"
        "org.mozilla.firefox.desktop"
        "code.desktop"
        "org.gnome.Nautilus.desktop"
      ];
    };
    settings."org/gnome/mutter" = {
      experimental-features = [
        "scale-monitor-framebuffer" # Enables fractional scaling (125% 150% 175%)
        "variable-refresh-rate" # Enables Variable Refresh Rate (VRR) on compatible displays
        "xwayland-native-scaling" # Scales Xwayland applications to look crisp on HiDPI screens
        "autoclose-xwayland" # automatically terminates Xwayland if all relevant X11 clients are gone
      ];
    };
    # 挂起恢复有问题
    settings."org/gnome/settings-daemon/plugins/power" = {
      # 禁用使用电池时的自动挂起
      sleep-inactive-battery-type = "nothing";
      # 禁用插入电源时的自动挂起
      sleep-inactive-ac-type = "nothing";
      # 设置电源按钮行为为nothing
      power-button-action = "nothing";
    };

    # nautilus view using list-view
    settings."org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
      use-tree-view = true;
      # NOTE: `show-hidden-files` here is deprecated and ignored since nautilus 43.
      # Nautilus now shares GTK's file-chooser setting, see below.
    };

    # Disable donation reminder in GNOME Settings
    # I'm so sorry for the GNOME developers, but I don't have the money to donate to GNOME, and I don't want to be reminded about it every time I open GNOME Settings.
    settings."org/gnome/settings-daemon/plugins/housekeeping" = {
      donation-reminder-enabled = false;
    };

    # Show hidden files in nautilus (and in GTK4 file chooser dialogs).
    # Nautilus reads `show-hidden` from `org.gtk.gtk4.Settings.FileChooser` at path
    # `/org/gtk/gtk4/settings/file-chooser/`, see
    # https://gitlab.gnome.org/GNOME/nautilus/-/blob/main/src/nautilus-global-preferences.c
    settings."org/gtk/gtk4/settings/file-chooser" = {
      show-hidden = true;
    };

    # 设置 GNOME Remote Desktop RDP 端口为 23389，并允许在占用时向后搜索 10 个端口
    settings."org/gnome/desktop/remote-desktop/rdp" = {
      # port = 23389; # 目前不知道为什么不起效
      # "negotiate-port" = true; # 目前不知道为什么不起效
      enable = true;
      view-only = false;
    };

    # settings."org/gnome/desktop/remote-desktop/rdp/headless" = {
    #  port = 23390; # 目前不知道为什么不起效
    #  "negotiate-port" = true; # 目前不知道为什么不起效
    #  enable = false;
    # };

    # 设置自定义快捷键

    settings."org/gnome/desktop/wm/keybindings" = {
      close = [
        "<Super>q"
        "<Alt>F4"
      ];

      # Alt+Tab 切换扁平窗口列表（switch-windows），Super+Tab 切换应用（switch-applications）。
      # schema 默认把 Alt+Tab 也写在 switch-applications 里，必须显式覆盖才能去掉。
      switch-windows = [ "<Alt>Tab" ];
      switch-windows-backward = [ "<Shift><Alt>Tab" ];
      switch-applications = [ "<Super>Tab" ];
      switch-applications-backward = [ "<Shift><Super>Tab" ];
    };

    settings."org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
      "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/"
    ];

    settings."org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Launch Terminal";
      command = "ghostty";
      binding = "<Super>Return";
    };

    settings."org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      name = "PowerOff Monitor";
      command = "dbus-send --session --dest=org.gnome.ScreenSaver --type=method_call /org/gnome/ScreenSaver org.gnome.ScreenSaver.SetActive boolean:true";
      binding = "PowerOff";
    };

    settings."org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      name = "PowerOff Monitor";
      command = "dbus-send --session --dest=org.gnome.ScreenSaver --type=method_call /org/gnome/ScreenSaver org.gnome.ScreenSaver.SetActive boolean:true";
      binding = "<Shift><Super>p";
    };

    settings."org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
      name = "Run Menu";
      command = "anyrun";
      binding = "<Super>d";
    };

    settings."org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4" = {
      name = "Open File Manager";
      command = "nautilus";
      binding = "<Super>e";
    };

    settings."org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
      name = "Open Mission Center";
      command = "missioncenter";
      binding = "<Ctrl><Shift>Escape";
    };
  };
}
