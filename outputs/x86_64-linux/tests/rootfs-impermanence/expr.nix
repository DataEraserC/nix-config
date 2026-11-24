{ lib, inputs, ... }:
let
  rootfsModule = ../../../../modules/nixos/base/custom/system/rootfs.nix;

  # The module owns one generated stage-1 script, so the guard evaluates the
  # module itself instead of reading a host: no host has to enable it, and the
  # retention period under test is chosen here.
  eval =
    rootfsConfig:
    (import (inputs.nixpkgs.outPath + "/nixos/lib/eval-config.nix") {
      system = "x86_64-linux";
      modules = [
        rootfsModule
        (
          { ... }:
          {
            nixpkgs.hostPlatform = "x86_64-linux";
            system.stateVersion = "26.11";
            boot.loader.grub.enable = false;
            modules.system.rootfs = rootfsConfig;
          }
        )
      ];
    }).config;

  btrfs = eval {
    enable = true;
    fsType = "btrfs";
    btrfsBlockDevice = "/dev/test-root";
    retentionPeriod = 13;
  };
  btrfsDefaultRetention = eval {
    enable = true;
    fsType = "btrfs";
    btrfsBlockDevice = "/dev/test-root";
  };
  tmpfs = eval {
    enable = true;
    fsType = "tmpfs";
  };
  disabled = eval { enable = false; };

  script = btrfs.boot.initrd.systemd.services.impermanence-setup.script;
  defaultScript = btrfsDefaultRetention.boot.initrd.systemd.services.impermanence-setup.script;

  createdBeforeSweep =
    let
      beforeCreate = builtins.head (
        lib.strings.splitString "btrfs subvolume create /btrfs_tmp/root" script
      );
      beforeSweep = builtins.head (
        lib.strings.splitString "for i in $(find /btrfs_tmp/old_roots/" script
      );
    in
    builtins.stringLength beforeCreate < builtins.stringLength beforeSweep;
in
{
  # The recursive delete must prefix the child path printed by
  # `btrfs subvolume list -o`; re-prefixing the caller's argument makes the
  # next list call read /btrfs_tmp/btrfs_tmp/... and abort the whole script.
  recursionUsesChildPath = lib.strings.hasInfix ''delete_subvolume_recursively "/btrfs_tmp/$child"'' script;
  recursionKeepsArgument = !lib.strings.hasInfix ''"/btrfs_tmp/$1"'' script;

  # A cleanup failure may not leave the host without a root subvolume.
  rootSubvolumeCreatedBeforeSweep = createdBeforeSweep;
  sweepFailureIsReported = lib.strings.hasInfix "impermanence-setup: WARNING" script;

  # Without -mindepth 1 the sweep can match /btrfs_tmp/old_roots itself and
  # delete the roots that are still inside the retention period. Plain mv
  # nests the new root inside an expired entry instead of failing.
  sweepStartsBelowOldRoots = lib.strings.hasInfix "-mindepth 1 -maxdepth 1 -mtime +13" script;
  rotationRejectsExistingTarget = lib.strings.hasInfix "mv -T /btrfs_tmp/root" script;

  # Option plumbing: the device and the retention period reach the script.
  blockDeviceIsUsed = lib.strings.hasInfix "mount -t btrfs /dev/test-root /btrfs_tmp" script;
  defaultRetentionIsUsed = lib.strings.hasInfix "-mtime +30" defaultScript;

  # The btrfs branch is what sysroot.mount depends on; the other shapes must
  # not grow a sweep service. nixpkgs adds x-initrd.mount to the option list,
  # so only membership is the module's contract.
  rootMountUsesSubvolRoot = lib.lists.elem "subvol=root" btrfs.fileSystems."/".options;
  rootMountComesFromBlockDevice =
    btrfs.fileSystems."/".device == "/dev/test-root" && btrfs.fileSystems."/".fsType == "btrfs";
  tmpfsBranchHasNoSweepService = !(tmpfs.boot.initrd.systemd.services ? impermanence-setup);
  disabledHasNoSweepService = !(disabled.boot.initrd.systemd.services ? impermanence-setup);
}
