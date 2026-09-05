{
  pkgs,
  nur-DataEraserC,
  config,
  myvars,
  ...
}:
let
  catppuccinVariant = "mocha";
  catppuccinAccent = "pink";
  catppuccinSize = "standard";

  catppuccinGtk = pkgs.catppuccin-gtk.override {
    variant = catppuccinVariant;
    accents = [ catppuccinAccent ];
    size = catppuccinSize;
  };
in
{
  # If your themes for mouse cursor, icons or windows don't load correctly,
  # try setting them with home.pointerCursor and gtk.theme,
  # which enable a bunch of compatibility options that should make the themes load in all situations.

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = nur-DataEraserC.packages.${pkgs.system}.sam-toki-mouse-cursors;
    # Sam Toki Mouse Cursors. Switch by changing the name:
    #   STMC_1_1_Standard              - Standard
    #   STMC_1_2_Standard_White        - Standard White
    #   STMC_1_3_Standard_Classic      - Standard Classic
    #   STMC_1_7_Standard_Left_Handed  - Standard Left-Handed
    #   STMC_2_1_45_Degree             - 45-Degree
    #   STMC_2_2_45_Degree_White       - 45-Degree White
    #   STMC_2_7_45_Degree_Left_Handed - 45-Degree Left-Handed
    #   STMC_3_1_Genshin               - Genshin
    #   STMC_3_2_Genshin_Elements      - Genshin Elements
    #   STMC_3_7_Genshin_Left_Handed   - Genshin Left-Handed
    #   STMC_4_1_Genshin_Nahida        - Genshin Nahida
    #   STMC_4_7_Genshin_Nahida_Left_Handed - Genshin Nahida Left-Handed
    #   STMC_5_1_BTR_Ahoge             - Bocchi the Rock (current)
    #   STMC_5_2_BTR_Ahoge_Nijika      - BTR Nijika
    #   STMC_5_3_BTR_Ahoge_Mix         - BTR Mix
    #   STMC_5_7_BTR_Ahoge_Left_Handed - BTR Left-Handed
    #   STMC_6_1_Genshin_Furina        - Genshin Furina
    #   STMC_6_7_Genshin_Furina_Left_Handed - Genshin Furina Left-Handed
    #   STMC_7_1_Silent_Witch          - Silent Witch
    #   STMC_7_2_Silent_Witch_Alt      - Silent Witch Alt
    #   STMC_7_7_Silent_Witch_Left_Handed - Silent Witch Left-Handed
    name = "STMC_6_1_Genshin_Furina";
    size = 32;
  };

  # Disable catppuccin cursors to avoid conflict with sam-toki-mouse-cursors
  catppuccin.cursors.enable = false;

  # set dpi for 4k monitor
  xresources.properties = {
    # dpi for Xorg's font
    "Xft.dpi" = 96;
    # or set a generic dpi
    "*.dpi" = 96;
  };

  # gtk's theme settings, generate files:
  #   1. ~/.gtkrc-2.0
  #   2. ~/.config/gtk-3.0/settings.ini
  #   3. ~/.config/gtk-4.0/settings.ini
  gtk = {
    enable = true;

    font = with pkgs; {
      name = "Maple Mono NF CN";
      package = maple-mono.NF-CN-unhinted;
      size = 11;
    };

    gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";

    gtk3 = {
      bookmarks = [
        "file:///home/${myvars.username}/Downloads/AyuGram%20Desktop"
        "file:///home/${myvars.username}/Apps/Wine"
        "file:///home/${myvars.username}/Documents"
        "file:///home/${myvars.username}/Downloads"
        "file:///home/${myvars.username}/Videos"
        "file:///home/${myvars.username}/Pictures"
        "file:///home/${myvars.username}/Music"
        "file:///home/${myvars.username}/Apps"
        "file:///home/${myvars.username}/nix-config"
        "file:///persistent"
        "file:///run/media/nixos/windows/Users/"
      ];
    };

    theme = {
      name = "catppuccin-${catppuccinVariant}-${catppuccinAccent}-${catppuccinSize}";
      package = catppuccinGtk;
    };

    gtk3.extraConfig = {
      "gtk-application-prefer-dark-theme" = "1";
    };
    gtk4.extraConfig = {
      "gtk-application-prefer-dark-theme" = "1";
    };
    # Some Applications (e.g. MissionCenter) only look for gtk4 settings, so we need to set the theme there as well.
    gtk4.theme = config.gtk.theme;
  };
}
