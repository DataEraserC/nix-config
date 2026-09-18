{ config, mylib, ... }:
let
  mkSymlink = mylib.mklinkRelativeToRoot;
in
{
  imports = [
    ../../linux/gui.nix
    ./jetbrains.nix
  ];

  programs.ssh.settings."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/idols-ai_id_ed25519";

  # We set this in outputs
  # modules.desktop.gaming.enable = true;
  # modules.desktop.niri.enable = true;

  # PC: keep the screen on longer than on the laptop.
  modules.desktop.hypridle = {
    keyboardBacklightTimeout = 900;
    screenOffTimeout = 1200;
    lockTimeout = 1800;
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

  # The desktop speakers are already loud, so use the broadcast-standard -23 dB.
  services.easyeffects.extraPresets."loudness-normalization".output."autogain#0".target = -23.0;
}
