{
  config,
  pkgs,
  pkgs-master,
  nixpak,
  myvars,
  mysecrets,
  ...
}:
let
  # effective password store directory shared with the sandboxed apps
  passwordStore =
    if
      (
        config.modules.outOfStoreSymlink.enable
        && (config.modules.outOfStoreSymlink.paths ? passwordStorePath)
      )
    then
      "/home/${myvars.username}/.local/share/password-store"
    else
      "${mysecrets}/PasswordStore";
  callArgs = {
    inherit passwordStore;
    mkNixPak = nixpak.lib.nixpak {
      inherit (pkgs) lib;
      inherit pkgs;
    };
    safeBind = sloth: realdir: mapdir: [
      (sloth.mkdir (sloth.concat' sloth.appDataDir realdir))
      (sloth.concat' sloth.homeDir mapdir)
    ];
  };
  wrapper = _pkgs: path: (_pkgs.callPackage path callArgs);
in
{
  # Add nixpaked Apps into nixpkgs, and reference them in home-manager or other nixos modules
  nixpkgs.overlays = [
    (_: super: {
      nixpaks = {
        qq = wrapper pkgs-master ./qq.nix;
        telegram-desktop = wrapper super ./telegram-desktop.nix;
        firefox = wrapper super ./firefox.nix;
      };
    })
  ];
}
