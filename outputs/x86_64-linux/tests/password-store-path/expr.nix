{
  myvars,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-gnome-wayland.config;
  homeCfg = cfg.home-manager.users.${myvars.username};
  target = "/home/${myvars.username}/.local/share/password-store";
  directoryOf = entry: if builtins.isAttrs entry then entry.directory else entry;
  preservedDirectories = map directoryOf (
    cfg.preservation.preserveAt."/persistent".users.${myvars.username}.directories
  );
  matchingMounts = builtins.filter (mount: mount.where == target) cfg.systemd.mounts;
in
{
  homeFileManaged = homeCfg.home.file ? ".local/share/password-store";
  preservedAsMount = builtins.elem target preservedDirectories;
  mountUnitPresent = matchingMounts != [ ];
}
