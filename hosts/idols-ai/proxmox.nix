{
  config,
  proxmox-nixos,
  ...
}:
{
  imports = [ proxmox-nixos.nixosModules.proxmox-ve ];

  services.proxmox-ve = {
    enable = false;
    ipAddress = "192.168.0.1";
  };

  nixpkgs.overlays = [
    proxmox-nixos.overlays.${config.nixpkgs.system}
  ];
}
