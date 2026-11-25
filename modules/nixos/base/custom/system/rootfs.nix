# Root-filesystem strategy for impermanent hosts (downstream-only module; both
# the option name and the implementation are ours, upstream has no equivalent).
#
# One parametrised module serves every shape that used to be divergent
# per-host impermanence_addon.nix copies:
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
            mkdir -p /btrfs_tmp/old_roots
            if [ -e /btrfs_tmp/root ]; then
                ${cfg.preBackupCommand}
                timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%d_%H:%M:%S")
                mv -T /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
                ${cfg.postBackupCommand}
            fi

            # The next root is created before any retention work: cleanup is
            # allowed to fail, but never to leave the host without a root
            # subvolume for sysroot.mount.
            btrfs subvolume create /btrfs_tmp/root

            delete_subvolume_recursively() {
                local IFS=$'\n'
                local path="$1"
                local child
                # -o prints children relative to the mounted top level, so the
                # mount point prefixes the child, never the path we were given.
                for child in $(btrfs subvolume list -o "$path" | cut -f 9- -d ' '); do
                    delete_subvolume_recursively "/btrfs_tmp/$child"
                done
                btrfs subvolume delete "$path"
            }

            # -mindepth 1 keeps the sweep on the retained roots: without it
            # /btrfs_tmp/old_roots itself can match -mtime, and the recursion
            # then deletes every root still being kept.
            for i in $(find /btrfs_tmp/old_roots/ -mindepth 1 -maxdepth 1 -mtime +${toString cfg.retentionPeriod}); do
                delete_subvolume_recursively "$i" \
                    || echo "impermanence-setup: WARNING: expired root $i was not deleted, it is kept; free it manually" >&2
            done

            umount /btrfs_tmp
          '';
        };
      })
    ]
  );
}
