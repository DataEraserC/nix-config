{
  pkgs,
  pkgs-stable,
  pkgs-master,
  pkgs-blender,
  nur-ryan4yin,
  nur-DataEraserC,
  blender-bin,
  ...
}:
let
  my_packages = with pkgs; [
    gimp
    # nur-DataEraserC.packages.${pkgs.system}.wechat_dev_tools_bin
  ];
in
{
  home.packages =
    with pkgs-stable;
    [
      # creative
      # krita # digital painting
      # musescore # music notation
      # pkgs-master.orca-slicer # 3d printer slicer app
      # bambu-studio # bambu 3d printer slicer app
      # pkgs-blender.blender # 3d modeling
    ]
    ++ my_packages;

  programs = {
    # live streaming
    obs-studio = {
      enable = pkgs.stdenv.hostPlatform.isx86_64;
      plugins = with pkgs.obs-studio-plugins; [
        # screen capture
        wlrobs
        # obs-ndi
        # obs-nvfbc
        # obs-teleport
        # obs-hyperion
        # droidcam-obs
        # obs-vkcapture
        obs-gstreamer
        input-overlay
        obs-multi-rtmp
        obs-source-clone
        # obs-shaderfilter
        # obs-source-record
        # obs-livesplit-one
        # looking-glass-obs
        # obs-vintage-filter
        # obs-command-source
        # obs-move-transition
        # obs-backgroundremoval
        # advanced-scene-switcher
        obs-pipewire-audio-capture
        obs-vaapi
        # obs-3d-effect
      ];
    };
  };
}
