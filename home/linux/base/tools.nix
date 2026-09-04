{
  pkgs,
  pkgs-unstable-etcher,
  ...
}:
{
  # Linux Only Packages, not available on Darwin
  home.packages = with pkgs; [
    # misc
    libnotify
    wireguard-tools # manage wireguard vpn manually, via wg-quick

    # TODO: move to other place
    # pkgs-unstable-etcher.etcher # create bootable usb
    # virt-viewer # vnc connect to VM, used by kubevirt
  ];
}
