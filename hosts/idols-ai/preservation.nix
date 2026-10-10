{
  preservation,
  lib,
  pkgs,
  myvars,
  ...
}:
let
  inherit (myvars) username;
in
{
  imports = [
    preservation.nixosModules.default
  ];

  preservation.enable = true;
  # pverservation required initrd using systemd.
  boot.initrd.systemd.enable = true;

  environment.systemPackages = [
    # Whole-filesystem disk usage (`-x` stays on one filesystem):
    #   sudo gdu -n -x /            # non-interactive, plain text
    #   sudo gdu -o /tmp/gdu.json / # JSON export
    pkgs.gdu
  ];

  # There are two ways to clear the root filesystem on every boot:
  ##  1. use tmpfs for /
  ##  2. (btrfs/zfs only)take a blank snapshot of the root filesystem and revert to it on every boot via:
  ##     boot.initrd.postDeviceCommands = ''
  ##       mkdir -p /run/mymount
  ##       mount -o subvol=/ /dev/disk/by-uuid/UUID /run/mymount
  ##       btrfs subvolume delete /run/mymount
  ##       btrfs subvolume snapshot / /run/mymount
  ##     '';
  #
  #  See also https://grahamc.com/blog/erase-your-darlings/

  # NOTE: preservation only mounts the directory/file list below to /persistent
  # If the directory/file already exists in the root filesystem you should
  # move those files/directories to /persistent first!
  preservation.preserveAt."/persistent" = {
    directories = [
      "/etc/NetworkManager/system-connections"
      "/etc/ssh"
      "/etc/nix/inputs"
      "/etc/secureboot" # lanzaboote - secure boot
      # my secrets
      "/etc/agenix/"

      "/var/log"
      # system caches (e.g. restic, plocate; slow to rebuild)
      "/var/cache"
      # General scratch space. It is re-creatable and can grow large, so keep it
      # off the root tmpfs and on the persistent volume. Contents only
      # accumulate between reboots: the tmpfiles rule below wipes it at boot.
      # World-writable scratch, so harden the bind mount like /tmp; the mode
      # must stay 1777 to match that `D!` rule.
      {
        directory = "/var/tmp";
        mode = "1777";
        mountOptions = [
          "nosuid"
          "nodev"
        ];
      }
      # btrbk state/home (SSH keys, cache). The owner must match the btrbk
      # module's `d /var/lib/btrbk 0750 btrbk btrbk` rule, which preservation
      # would otherwise override with the default root:root.
      {
        directory = "/var/lib/btrbk";
        user = "btrbk";
        group = "btrbk";
        mode = "0750";
      }
      # CUPS state (the print spool lives in /var/spool/cups, not here)
      "/var/lib/cups"

      # system-core
      "/var/lib/nixos"
      "/var/lib/systemd"
      # upower device battery history (e.g. Magic Trackpad)
      "/var/lib/upower"
      {
        directory = "/var/lib/private";
        mode = "0700";
      }

      # containers
      # "/var/lib/docker"
      "/var/lib/cni"
      "/var/lib/containers"

      # virtualisation
      "/var/lib/libvirt"
      "/var/lib/qemu"
      "/var/lib/waydroid"

      # network
      "/var/lib/bluetooth"
      "/var/lib/NetworkManager"
      "/var/lib/iwd"
      "/var/lib/tailscale"

      # logrotate state. Persist the directory: a single-file bind mount cannot
      # be replaced by logrotate's atomic rename() (EBUSY).
      "/var/lib/logrotate"

      # Mayuri spec
      # pgyvpn
      "/var/lib/pgyvpn" # Oray PgyVisitor state

      # zerotier
      "/var/lib/zerotier-one"

      # alist
      "/var/lib/openlist"
      # daed
      "/etc/daed/"

      # cliproxyapi (generated config.yaml, management key and auth/provider files)
      {
        directory = "/var/lib/cliproxyapi";
        # user = "cliproxyapi";
        # group = "cliproxyapi";
        mode = "0700";
      }

      # new-api (database)
      {
        directory = "/var/lib/new-api";
        # user = "new-api";
        # group = "new-api";
        mode = "0700";
      }

      # m365-copilot2api (accounts, tokens, sessions, API keys, settings)
      {
        directory = "/var/lib/m365-copilot2api";
        # user = "m365-copilot2api";
        # group = "m365-copilot2api";
        mode = "0700";
      }

      # opencode2api (config.json, model caches, server key)
      {
        directory = "/var/lib/opencode2api";
        mode = "0700";
      }

      # omniroute (SQLite database, generated server.env secrets, logs)
      {
        directory = "/var/lib/omniroute";
        mode = "0700";
      }

      # ccache
      "/var/cache/ccache"

      # for android sign
      # TODO: move to agenix/sop
      "/etc/secrets/android-keys"

      # for pve-nixos
      "/var/lib/pve-cluster"

      {
        directory = "/var/lib/gnome-remote-desktop";
        # user = "gnome-remote-desktop";
        # group = "gnome-remote-desktop";
        mode = "0755";
      }
      {
        directory = "/etc/gnome-remote-desktop";
        # user = "gnome-remote-desktop";
        # group = "gnome-remote-desktop";
        mode = "0755";
      }

      # shared sunshine identity data (see hosts/idols-ai/sunshine.nix)
      {
        directory = "/var/lib/sunshine";
        # group = "sunshine";
        mode = "2770";
      }
    ];
    files = [
      # auto-generated machine ID
      {
        file = "/etc/machine-id";
        inInitrd = true;
      }
    ];

    # the following directories will be passed to /persistent/home/$USER
    users.${username} = {
      commonMountOptions = [
        "x-gvfs-hide"
      ];
      directories = [
        # ======================================
        # XDG Directories
        # ======================================

        "Desktop"
        "Downloads"
        "Music"
        "Pictures"
        "Documents"
        "Videos"
        "Templates"

        ".gnome"

        # Keep .cache off tmpfs to avoid high RAM usage; many apps use it and it is storage-heavy.
        ".cache"

        # NOTE: do NOT persist ~/.local/share/Trash here. The trash crate (nushell
        # `rm --trash`) picks the home trash only when the file's mount topdir equals
        # the trash dir's topdir; a bind-mounted Trash dir would make files straight
        # under $HOME fail with EACCES (it would try /.Trash-$uid). The home trash on
        # tmpfs is lost on reboot, which is acceptable: scattered per-mount
        # .Trash-$uid dirs on persistent volumes are covered by the trash-empty
        # retention timer (modules/nixos/base/trash.nix).

        # ======================================
        # Codes / Work / Playground
        # ======================================
        "codes" # for personal code
        "work" # work code tree
        "src" # third-party source checkouts
        "nix-config"
        "tmp"

        # ======================================
        # Nix / Home Manager Profiles
        # ======================================

        ".local/state/home-manager"
        ".local/state/nix/profiles"
        ".local/state/noctalia" # shell settings, notification/clipboard history
        ".local/share/nix"

        # rclone configuration and credentials
        ".config/rclone"

        # ======================================
        # IDE / Editors
        # ======================================

        # vscode
        ".vscode"
        ".config/Code"
        ".vscode-insiders"
        ".config/Code - Insiders"
        ".config/vscode-sqltools"
        # application-shared storage (VSCODE_SHARED / `sharedDataFolderName`).
        # The workspace-trust list lives in
        # `sharedStorage/state.vscdb` (`content.trust.model.key`), so without this
        # every folder has to be trusted again after each reboot.
        ".vscode-shared"
        # remote-ssh server install cache; persisted so it is not re-downloaded
        # (and re-patched by auto-fix-vscode-server) after every reboot.
        ".vscode-server"

        # zed
        ".config/zed"
        ".local/share/zed"

        # ai agents
        ".agents" # skills for all agents
        ".config/agents"
        ".codex"
        ".dsh" # DeepSeek Harness
        ".pi"
        ".config/opencode"
        ".local/share/opencode"
        ".local/state/opencode"
        ".dsh"
        ".dsh-tui"

        # pi coding agent (sessions under ~/.pi/agent/sessions)
        ".pi"

        # ctx7 docs lookup login
        {
          directory = ".config/context7";
          mode = "0700";
        }
        # Legacy ctx7 login, still read: ctx7 cannot rename it across the two bind mounts.
        {
          directory = ".context7";
          mode = "0700";
        }

        # nvim
        ".local/share/nvim"
        ".local/state/nvim"

        # ======================================
        # TUIOS (terminal window manager)
        # ======================================
        # Without .local/state/tuios the daemon has no saved session state to
        # restore after a reboot, and every session is lost.

        # session structure (resurrection), plus each pane's saved history
        {
          directory = ".local/state/tuios";
          mode = "0700";
        }
        # project-tape trust store and tape recordings
        {
          directory = ".local/share/tuios";
          mode = "0700";
        }
        # layout templates (config.toml is a Home Manager symlink into the repo)
        ".config/tuios"

        # Joplin
        ".config/joplin" # tui client
        ".config/Joplin" # joplin-desktop

        ".local/share/jupyter"
        ".ipython"

        # ======================================
        # Cloud Native
        # ======================================
        {
          directory = ".aws";
          mode = "0700";
        }
        {
          directory = ".aliyun";
          mode = "0700";
        }
        {
          directory = ".config/gcloud";
          mode = "0700";
        }
        {
          directory = ".config/gh";
          mode = "0700";
        }
        {
          directory = ".kube";
          mode = "0700";
        }
        ".terraform.d/plugin-cache" # terraform's plugin cache

        # ======================================
        # language package managers
        # ======================================
        ".npm" # typsescript/javascript
        "go"
        ".cargo" # rust
        ".m2" # java maven
        ".gradle" # java gradle
        ".conda" # python generated by `conda-shell`
        ".local/bin"
        # python uv
        ".local/share/uv"

        # ======================================
        # Security
        # ======================================

        {
          directory = ".gnupg";
          mode = "0700";
        }
        # hand-edited secret config; Nix does not deploy it
        {
          directory = ".secrets";
          mode = "0700";
        }
        {
          directory = ".ssh";
          mode = "0700";
        }
        {
          directory = ".pki";
          mode = "0700";
        }
        # {
        #   # symlinked to ${mysecrets}/PasswordStore, no need to preserve
        #   directory = ".local/share/password-store";
        #   mode = "0700";
        # }
        {
          # gnmome keyrings
          directory = ".local/share/keyrings";
          mode = "0700";
        }

        # ======================================
        # Games / Media
        # ======================================

        "Games"
        # .desktop entries created by games/installers (including the umu
        # launchers the nix-config-umu-game skill generates). Home Manager
        # rewrites its mimeapps.list symlink into the bind mount at activation,
        # so that survives too.
        ".local/share/applications"
        ".steam"
        ".config/MangoHud"
        ".config/blender"

        ".local/share/umu"

        ".local/share/Steam"
        ".local/state/Heroic"
        ".config/heroic"
        ".config/lutris"
        ".local/share/lutris"
        ".local/share/wine/drive_c/users/${username}"
        ".local/share/tiled"

        ".local/share/GOG.com"
        ".local/share/StardewValley"
        ".local/share/feral-interactive"
        ".local/share/qq-bridge"

        # ======================================
        # Instant Messaging
        # ======================================
        ".config/QQ"

        ".local/share/TelegramDesktop"
        ".local/share/AyuGramDesktop"

        # ======================================
        # Meeting / Remote Desktop / Recording
        # ======================================
        ".zoom"
        ".config/obs-studio"
        ".config/Moonlight Game Streaming Project"
        ".config/sunshine"
        ".config/freerdp"

        ".config/remmina"
        ".local/share/remmina"

        # ======================================
        # browsers
        # ======================================
        ".mozilla"
        ".config/google-chrome"
        ".config/chromium"
        ".config/google-chrome-unstable"
        ".config/BraveSoftware/Brave-Origin"
        ".config/microsoft-edge"

        # ======================================
        # CLI data
        # ======================================
        ".local/share/atuin"
        ".local/share/zoxide"
        ".local/share/direnv"
        ".local/share/k9s"

        # ======================================
        # Containers
        # ======================================
        ".local/share/containers"
        # nixpak app's data
        {
          directory = ".var";
          mode = "0700";
        }

        # ======================================
        # Misc
        # ======================================

        # Mihomo (native core): sources spec, generator and config all live here
        # (contains subscription secrets, hence 0700).
        {
          directory = ".config/mihomo";
          mode = "0700";
        }

        # Orca Slicer - 3D Printer Slicer
        ".local/share/orca-slicer"
        ".config/OrcaSlicer"

        # Bambu Studio - 3D Printer Slicer
        ".local/share/bambu-studio"
        ".config/BambuStudio"

        # Audio
        ".config/pulse"
        ".local/state/wireplumber"

        # go-musicfox - TUI NetEase Cloud Music client
        # ~/.config/go-musicfox/config.toml is force-managed by Home Manager
        # (see home/linux/gui/base/go-musicfox/default.nix) and reset on each
        # rebuild; this keeps the runtime themes/ directory and the app's
        # between-rebuild config edits.
        ".config/go-musicfox"
        ".local/share/go-musicfox" # login cookie + library db
        ".local/state/go-musicfox" # logs

        # Digital Painting
        ".local/share/krita"

        # Japanese IME
        ".config/mozc" # used by fcitx5-mozc

        # Vinput voice input (fcitx5-vinput): core config.json + downloaded
        # sherpa-onnx models (~/.local/share/vinput/models/). Without these the
        # daemon starts with "Local ASR provider model is not configured" after
        # every reboot. Setup commands: home/linux/gui/base/vinput/README.md
        ".config/vinput"
        ".local/share/vinput"

        ".config/nushell"

        # Mayuri Spec

        # ======================================
        # Apps
        # ======================================

        # piliplus
        ".local/share/com.example.piliplus/"

        # persist data for android studio
        ".local/share/Google/"

        ".local/share/DBeaverData/"

        ".local/share/authenticator/"
        ".local/share/hmcl" # HMCL launcher shared accounts/config

        ".wine"
        ".winboat"
        # WinBoat VM disk image lives in ~/winboat (bind-mounted into the
        # container as /storage). It is NOT under ~/.winboat, so it must be
        # preserved too - otherwise the ephemeral root wipes the Windows disk
        # on every reboot and podman fails with: crun: cannot stat
        # `/home/nixos/winboat`: No such file or directory
        "winboat"
        ".hmcl" # HMCL launcher accounts/config
        ".minecraft"
        "GOG Games"

        "Apps" # some apps temporarily store at here

        ".config/Ryujinx"
        ".config/yuzu"
        ".config/suyu"
        ".config/lutris"
        ".config/gnome-boxes"
        "Android"
        ".android"
        ".config/.android"
        "workspace"
        "eclipse-workspace"
        ".Genymobile"
        "AndroidStudioProjects"
        "IdeaProjects"
        ".jdks"

        # persist gnome shell extensions clipboard-indicator
        ".cache/clipboard-indicator@tudmotu.com"

        # persist paired device data for gsconnect
        # cert and key
        ".config/gsconnect"

        # nix-index
        ".cache/nix-index"

        ".tldr"

        # cisco packet tracer
        "pt"

        # email clients profiles
        ".thunderbird"

        # ServerBox
        ".config/ServerBox"

        "BetterUniverse"

        # clash
        ".config/clash"
        ".config/clash-verge"
        ".config/clash-nyanpasu"
        ".config/mihomo-party"
        ".config/flclash"
        # v2ray
        ".config/qv2ray"
        ".config/nekoray"
        ".config/Throne"
        # gg
        ".config/gg"

        # test niri
        ".config/niri"

        # ai related file dirs
        "invokeai"
        ".textgen"
        ".config/LaphaeLaicmd"
        ".config/aichat"
        # NOTE: this can be remove bcs we use `services.ollama` which place files in `/var/lib/ollama` by default
        ".ollama"
        # NOTE: this can be remove bcs we use `services.open-webui` which place state files in `/var/lib/open-webui` by default
        ".config/open-webui"
        ".config/CherryStudio"
        ".cache/huggingface"
        ".lingma"
        ".modlens"
        # antigravity-cli (`agy`, used by modlens): OAuth login + config live
        # in ~/.gemini (config/) and state/logs in ~/.gemini/antigravity-cli/.
        # Persisted so the login survives the root-fs wipe on boot.
        ".gemini"

        ".vmware"
        "VirtualBox VMs"
        ".config/VirtualBox"
        ".config/lxc"
        ".config/libvirt"

        ".config/.cpolar"
        ".config/oray-tools"
        ".config/aDrive"
        ".config/baidunetdisk"
        ".config/wechat-devtools"
        ".config/JetBrains"
        ".config/io.hoppscotch.desktop"
        ".config/ncmpcpp"
        ".config/uGet"
        ".config/Motrix"
        ".config/icalingua"
        ".config/MuseScore"
        ".config/ghc"
        ".config/Kingsoft"
        ".config/libreoffice"
        ".config/onlyoffice"
        ".config/Genymobile"
        # this is set to 0700
        # ".config/gh"
        ".config/go-musicfox"
        ".config/GIMP"
        ".config/anytype"
        ".config/obs-studio"
        ".config/kdeconnect"
        ".config/DingTalk"
        ".config/bilibili"
        ".config/Google"
        ".config/Moonlight Game Streaming Project"

        # kde related
        ".config/kdedefaults"

        # Trash Bin(not work yet)
        # https://github.com/nix-community/impermanence/issues/147

        ".local/share/Trash"

        ".cache/tlrc"

        ".net/devtunnel"

        # for nautilus pre dir config
        ".local/share/gvfs-metadata"

        # nvfetcher cache
        "_sources"

        # Trash Bin
        ".Trash-1000"
      ];
      files = [
        {
          file = ".config/zoomus.conf";
          how = "symlink";
        }
        {
          file = ".config/zoom.conf";
          how = "symlink";
        }
      ];
    };
  };

  # Keep logrotate's state inside the directory preserved above instead of the
  # default /var/lib/logrotate.status (a mount point `rename()` cannot replace).
  services.logrotate.extraArgs = [
    "--state"
    "/var/lib/logrotate/status"
  ];

  # Create some directories with custom permissions.
  #
  # In this configuration the path `/home/butz/.local` is not an immediate parent
  # of any persisted file so it would be created with the systemd-tmpfiles default
  # ownership `root:root` and mode `0755`. This would mean that the user `butz`
  # could not create other files or directories inside `/home/butz/.local`.
  #
  # Therefore systemd-tmpfiles is used to prepare such directories with
  # appropriate permissions.
  #
  # Note that immediate parent directories of persisted files can also be
  # configured with ownership and permissions from the `parent` settings if
  # `configureParent = true` is set for the file.
  systemd.tmpfiles.settings.preservation =
    let
      permission = {
        user = username;
        group = lib.mkForce username;
        mode = lib.mkForce "0750";
      };
    in
    {
      "/home/${username}/.config".d = permission;
      "/home/${username}/.local".d = permission;
      "/home/${username}/.local/share".d = permission;
      "/home/${username}/.local/state".d = permission;
      "/home/${username}/.local/state/nix".d = permission;
      "/home/${username}/.terraform.d".d = permission;
    };

  # /var/tmp is re-creatable scratch, but it must not consume RAM, so it is
  # bind-mounted onto the persistent volume above. Wipe it at boot (mirrors
  # nixpkgs `boot.tmp.cleanOnBoot` for /tmp) so contents only accumulate
  # between reboots.
  #
  # Crash dumps live in the persisted /var/lib/systemd and can contain secrets
  # copied out of process memory, so don't keep them across reboots either.
  systemd.tmpfiles.rules = [
    "D! /var/tmp 1777 root root"
    "D! /var/lib/systemd/coredump 0755 root root"
  ];

  # systemd-machine-id-commit.service would fail but it is not relevant
  # in this specific setup for a persistent machine-id so we disable it
  #
  # see the firstboot example below for an alternative approach
  systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

  # let the service commit the transient ID to the persistent volume
  systemd.services.systemd-machine-id-commit = {
    unitConfig.ConditionPathIsMountPoint = [
      ""
      "/persistent/etc/machine-id"
    ];
    serviceConfig.ExecStart = [
      ""
      "systemd-machine-id-setup --commit --root /persistent"
    ];
  };
}
