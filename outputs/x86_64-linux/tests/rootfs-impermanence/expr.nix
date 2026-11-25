{ lib, outputs, ... }:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  script = cfg.boot.initrd.systemd.services.impermanence-setup.script;
in
{
  fsType = cfg.modules.system.rootfs.fsType;
  retentionPeriod = cfg.modules.system.rootfs.retentionPeriod;

  # The recursion has to prefix the child path reported by
  # `btrfs subvolume list -o`, never the path it was called with: prefixing the
  # argument builds /btrfs_tmp/btrfs_tmp/... and the sweep then dies.
  recursionUsesChild = lib.strings.hasInfix ''delete_subvolume_recursively "/btrfs_tmp/$child"'' script;
  recursionReusesArgument = lib.strings.hasInfix ''delete_subvolume_recursively "/btrfs_tmp/$1"'' script;

  # A cleanup failure may not remove the host's ability to boot: the next root
  # subvolume exists before the retention sweep starts.
  createBeforeSweep =
    let
      beforeCreate = builtins.head (
        lib.strings.splitString "btrfs subvolume create /btrfs_tmp/root" script
      );
      beforeSweep = builtins.head (
        lib.strings.splitString "for i in $(find /btrfs_tmp/old_roots/" script
      );
    in
    builtins.stringLength beforeCreate < builtins.stringLength beforeSweep;

  # Expired entries are swept one by one, and a survivor is announced.
  sweepKeepsOldRootsDir = lib.strings.hasInfix "-mindepth 1 -maxdepth 1 -mtime" script;
  sweepIsLoud = lib.strings.hasInfix "WARNING" script;

  # Rotating onto an existing name must fail instead of nesting one root
  # inside another, which is what arms the sweep above.
  rotationIsAtomic = lib.strings.hasInfix "mv -T /btrfs_tmp/root" script;
}
