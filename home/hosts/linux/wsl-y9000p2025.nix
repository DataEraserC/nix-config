{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
{
  imports = [
    # Pi Coding Agent, shared with idols-ai.
    ../../base/gui/ai/pi-coding-agent.nix
  ];

  # modules.desktop = {
  #   hyprland = {
  #     nvidia = true;
  #     settings = {
  #       # Configure your Display resolution, offset, scale and Monitors here, use `hyprctl monitors` to get the info.
  #       #   highres:      get the best possible resolution
  #       #   auto:         position automatically
  #       #   1.5:          scale to 1.5 times
  #       #   bitdepth,10:  enable 10 bit support
  #       monitor = "eDP-1,2560x1600@60,0x0,1";
  #     };
  #   };
  # };
  # modules.editors.emacs = {
  #   enable = true;
  # };

  # This machine's own SSH identity: wsl-y9000p2025_id_ed25519. Same shape as
  # home/hosts/linux/idols-ai.nix; WSL forwards the agent (mkForce wins over the
  # shared `Host *` default) and pins every connection to its own identity.
  programs.ssh.settings = {
    "*" = {
      ForwardAgent = lib.mkForce true;
      IdentitiesOnly = true;
      IdentityFile = [ "${config.home.homeDirectory}/.ssh/wsl-y9000p2025_id_ed25519" ];
    };
    "github.com".identityFile = "${config.home.homeDirectory}/.ssh/wsl-y9000p2025_id_ed25519";
    "zerotier_devices" = {
      HostName = "10.147.20.*";
      MACs = "hmac-sha1,hmac-sha1-96,hmac-sha2-256,hmac-sha2-512,hmac-md5";
    };
  };
  home.stateVersion = "26.05";
  home.packages = [
    # nur-DataEraserC.packages.${pkgs.system}.llqqnt
    # nur-DataEraserC.packages.${pkgs.system}.bqqnt
  ];
}
