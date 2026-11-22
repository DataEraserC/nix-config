# Root-filesystem strategy for impermanent hosts (downstream-only module; both
# the option name and the implementation are ours, upstream has no equivalent).
#
# One parametrised module serves every shape that used to be three divergent
# per-host copies (hosts/idols-ai/impermanence_addon.nix and the two WSL
# impermanence_addon.nix files):
#
#   - fsType "tmpfs": root on tmpfs (the WSL hosts).
#   - fsType "btrfs": root subvolume wiped at every boot through a systemd
#     initrd service, with retention and optional pre/post backup hooks
#     (idols-ai). nixpkgs 26.11 removed the scripted initrd, so the systemd
#     variant is the only one implemented.
#
# "/" is declared as a plain fileSystems entry (mkForce for btrfs); hosts that
# run disko keep declaring their disks in disko-fs.nix and simply set the
# options here.
{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.system.rootfs;
in
{
  options.modules.system.rootfs = {
    enable = lib.mkEnableOption "the impermanent root-filesystem strategy";

    fsType = lib.mkOption {
      type = lib.types.enum [
        "tmpfs"
        "btrfs"
      ];
      default = "tmpfs";
      description = "The filesystem type for the root filesystem.";
    };

    btrfsBlockDevice = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The block device for the btrfs root filesystem.";
    };

    retentionPeriod = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Retention period for old root subvolumes (in days).";
    };

    preBackupCommand = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The command to run before the root subvolume is rotated.";
    };

    postBackupCommand = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The command to run after the root subvolume is rotated.";
    };

    afters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional systemd units to order after for the impermanence-setup service (e.g. the LUKS mapper device).";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.fsType == "btrfs" -> cfg.btrfsBlockDevice != "";
            message = "modules.system.rootfs: fsType=btrfs requires btrfsBlockDevice to be set";
          }
        ];
      }

      # TMPFS SUPPORT
      (lib.mkIf (cfg.fsType == "tmpfs") {
        fileSystems."/" = {
          device = "tmpfs";
          fsType = "tmpfs";
          # set mode to 755, otherwise systemd will set it to 777, which causes problems.
          # relatime: Update inode access times relative to modify or change time.
          options = [
            "relatime"
            "mode=755"
          ];
        };
      })

      # BTRFS SUPPORT
      (lib.mkIf (cfg.fsType == "btrfs") {
        fileSystems."/" = lib.mkForce {
          device = cfg.btrfsBlockDevice;
          fsType = "btrfs";
          options = [ "subvol=root" ];
        };

        boot.initrd.systemd.services.impermanence-setup = lib.mkForce {
          description = "Impermanence setup for btrfs root subvolume";
          wantedBy = [ "initrd.target" ];
          before = [
            "initrd.target"
            "sysroot.mount"
          ];
          after = [ "cryptsetup.target" ] ++ cfg.afters;
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = ''
            mkdir -p /btrfs_tmp
            mount -t btrfs ${cfg.btrfsBlockDevice} /btrfs_tmp
            if [ -e /btrfs_tmp/root ]; then
                ${cfg.preBackupCommand}
                mkdir -p /btrfs_tmp/old_roots
                timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%d_%H:%M:%S")
                mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
                ${cfg.postBackupCommand}
            fi

            delete_subvolume_recursively() {
                IFS=$'\n'
                for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
                    delete_subvolume_recursively "/btrfs_tmp/$1"
                done
                btrfs subvolume delete "$1"
            }

            for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +${toString cfg.retentionPeriod}); do
                delete_subvolume_recursively "$i"
            done

            btrfs subvolume create /btrfs_tmp/root
            umount /btrfs_tmp
          '';
        };
      })
    ]
  );
}
