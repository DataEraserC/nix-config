{ config, mylib, ... }:
let
  mkSymlink = mylib.mklinkRelativeToRoot;
in
{
  imports = [ ../../linux/gui.nix ];

  programs.ssh.settings."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/idols-ai_id_ed25519";

  # We set this in outputs
  # modules.desktop.gaming.enable = true;
  # modules.desktop.niri.enable = true;

  programs.zed-editor.userSettings = {
    ui_font_size = 18.0;
    buffer_font_size = 17.0;
    agent_ui_font_size = 18.0;
    agent_buffer_font_size = 17.0;
  };

  programs.jetbrains.enable = true;

  xdg.configFile."niri/niri-hardware.kdl".source =
    mkSymlink config "hosts/idols-ai/niri-hardware.kdl";
}
