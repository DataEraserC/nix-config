{
  config,
  lib,
  mylib,
  ...
}:
let
  mkSymlink = mylib.mklinkRelativeToRoot;
  cfgNiri = config.modules.desktop.niri;
  cfgGnomeWayland = config.modules.desktop.gnome-wayland;
in
{
  imports = [
    ../../linux/gui.nix
    ./jetbrains.nix
  ];

  modules.desktop.vinput.enable = true;

  # 暂时切回 fcitx5；取消注释即可重新启用 cyime（仅 GNOME Wayland 变体）。
  # modules.desktop.cyime.enable = lib.mkIf cfgGnomeWayland.enable true;
  # modules.cyime-ice.enable = lib.mkIf cfgGnomeWayland.enable true;

  # This machine's own SSH identity: idols-ai_id_ed25519 with its RSA sibling.
  # The .pub files are installed by home/base/tui/ssh.nix on every device.
  programs.ssh.settings = {
    "*".IdentityFile = map (name: "${config.home.homeDirectory}/.ssh/${name}") [
      "idols-ai_id_ed25519"
      "idols-ai_id_rsa"
    ];
    "github.com".identityFile = "${config.home.homeDirectory}/.ssh/idols-ai_id_ed25519";
  };

  # We set this in outputs
  # modules.desktop.gaming.enable = true;
  # modules.desktop.niri.enable = true;
  modules.gaming-stack.enable = true;

  # PC: keep the screen on longer than on the laptop. The downstream variant
  # (Noctalia lock + niri power-off listeners) is selected for the niri variants.
  modules.desktop.hypridle = {
    # Niri requires this module, and this module requires Niri to provide functionality.
    enable = cfgNiri.enable;
    implementation = "downstream";
    keyboardDevice = "platform::kbd_backlight";
    keyboardBacklightTimeout = 180;
    screenOffTimeout = 120;
    lockTimeout = 600;
  };

  programs.zed-editor.userSettings = {
    ui_font_size = 18.0;
    buffer_font_size = 17.0;
    agent_ui_font_size = 18.0;
    agent_buffer_font_size = 17.0;
  };

  programs.jetbrains.enable = true;

  xdg.configFile."niri/niri-hardware.kdl".source =
    mkSymlink config "hosts/idols-ai/niri-hardware.kdl";

  xdg.configFile."monitors.xml" = lib.mkIf cfgGnomeWayland.enable {
    source = mkSymlink config "hosts/idols-ai/monitors.xml";
  };

  # Keep Noctalia's network widgets on the physical uplink, not the Mihomo TUN.
  xdg.configFile."noctalia/host-ai.toml".source = ./idols-ai/noctalia.toml;

  # The desktop speakers are already loud, so use the broadcast-standard -23 dB.
  services.easyeffects.extraPresets."loudness-normalization".output."autogain#0".target = -23.0;
}
