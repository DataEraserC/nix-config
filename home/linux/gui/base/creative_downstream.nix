# Downstream creative apps, kept in a separate file so the upstream
# creative.nix stays comment-delta only (list options concatenate across
# module definitions).
{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    gimp
  ];

  # OBS with the downstream plugin set (upstream ships nixpaks.obs-studio,
  # whose plugins are bundled by the wrapper; the module form takes the
  # plugin list explicitly and is commented out in creative.nix).
  programs.obs-studio = {
    enable = pkgs.stdenv.hostPlatform.isx86_64;
    plugins = with pkgs.obs-studio-plugins; [
      # screen capture
      wlrobs
      # obs-ndi
      # obs-teleport
      obs-gstreamer
      input-overlay
      obs-multi-rtmp
      obs-source-clone
      obs-pipewire-audio-capture
      obs-vaapi
    ];
  };
}
