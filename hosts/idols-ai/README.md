# Host - AI

Desktop (NixOS + preservation, LUKS + btrfs on nvme). Disk layout is declarative via
[disko](./disko-fs.nix) (target device: **nvme1n1**).

Related:

- [nixos-installer README](/nixos-installer/README.md) – install from ISO using disko
- [disko-fs.nix](./disko-fs.nix) – main disk layout (ESP + LUKS + btrfs). From
  `nix-config/nixos-installer`:  
  `nix run github:nix-community/disko -- --mode destroy,format,mount ../hosts/idols-ai/disko-fs.nix`
- [disko-fs-media.nix](./disko-fs-media.nix) – media disk layout (LUKS + btrfs at /persistent/media)

## TODOs

1. Install DCGM-Exporter on `ai` to monitor the GPU status.

## Info

Current disk status and mountpoints (example; after migration layout is on nvme1n1):

```bash
› df -Th
Filesystem                Type      Size  Used Avail Use% Mounted on
/dev/mapper/nixos-luks btrfs     1.9T  1.5T  407G   79% /
tmpfs                  tmpfs     7.7G   13M  7.7G    1% /run
/dev/mapper/nixos-luks btrfs     1.9T  1.5T  407G   79% /persistent
/dev/mapper/nixos-luks btrfs     1.9T  1.5T  407G   79% /nix
devtmpfs               devtmpfs  1.6G     0  1.6G    0% /dev
tmpfs                  tmpfs      16G  232M   16G    2% /dev/shm
efivarfs               efivarfs  268K  238K   26K   91% /sys/firmware/efi/efivars
none                   tmpfs     1.0M     0  1.0M    0% /run/credentials/systemd-journald.service
/dev/mapper/nixos-luks btrfs     1.9T  1.5T  407G   79% /btr_pool
/dev/mapper/nixos-luks btrfs     1.9T  1.5T  407G   79% /gnu
/dev/mapper/nixos-luks btrfs     1.9T  1.5T  407G   79% /snapshots
/dev/mapper/nixos-luks btrfs     1.9T  1.5T  407G   79% /swap
/dev/mapper/nixos-luks btrfs     1.9T  1.5T  407G   79% /tmp
/dev/nvme0n1p3         fuseblk   953G  708G  246G   75% /run/media/nixos/windows
/dev/nvme1n1p1         vfat      597M  102M  496M   17% /boot
tmpfs                  tmpfs      16G  1.7M   16G    1% /run/wrappers
none                   tmpfs     1.0M  4.0K 1020K    1% /run/credentials/libvirtd.service
tmpfs                  tmpfs     3.1G   56K  3.1G    1% /run/user/60578
tmpfs                  tmpfs     250M     0  250M    0% /var/lib/incus/devices
tmpfs                  tmpfs     100K     0  100K    0% /var/lib/incus/shmounts
tmpfs                  tmpfs     100K     0  100K    0% /var/lib/incus/guestapi
tmpfs                  tmpfs     3.1G  196K  3.1G    1% /run/user/1000

~
› lsblk
NAME           MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS
nvme0n1        259:0    0 953.9G  0 disk
├─nvme0n1p1    259:2    0   100M  0 part
├─nvme0n1p2    259:3    0    16M  0 part
├─nvme0n1p3    259:4    0 952.8G  0 part  /run/media/nixos/windows
└─nvme0n1p4    259:5    0  1002M  0 part
nvme1n1        259:1    0   1.9T  0 disk
├─nvme1n1p1    259:6    0   598M  0 part  /boot
└─nvme1n1p2    259:7    0   1.9T  0 part
  └─nixos-luks 254:0    0   1.9T  0 crypt /home/nixos/.claude.json
                                          /gnu/store
                                          /tmp
                                          /swap
                                          /snapshots
                                          /gnu
                                          /btr_pool
                                          /persistent/home/nixos/.cache/tlrc
                                          /home/nixos/.cache/tlrc
                                          /persistent/home/nixos/.cache/nix-index
                                          /persistent/home/nixos/.cache/clipboard-indicator@tudmotu.com
                                          /home/nixos/.cache/nix-index
                                          /home/nixos/.cache/clipboard-indicator@tudmotu.com
                                          /persistent/home/nixos/.cache/huggingface
                                          /home/nixos/.cache/huggingface
                                          /var/log
                                          /var/lib/zerotier-one
                                          /var/lib/waydroid
                                          /var/lib/tailscale
                                          /var/lib/systemd
                                          /var/lib/qemu
                                          /var/lib/pve-cluster
                                          /var/lib/private
                                          /var/lib/pgyvpn
                                          /var/lib/openlist
                                          /var/lib/nixos
                                          /var/lib/netbird-homelab
                                          /var/lib/lxd
                                          /var/lib/lxc
                                          /var/lib/libvirt
                                          /var/lib/iwd
                                          /var/lib/gnome-remote-desktop
                                          /var/lib/flatpak
                                          /var/lib/containers
                                          /var/lib/cni
                                          /var/lib/bluetooth
                                          /var/lib/NetworkManager
                                          /var/cache/davfs2
                                          /var/cache/ccache
                                          /home/nixos/workspace
                                          /home/nixos/work
                                          /home/nixos/tmp
                                          /home/nixos/pt
                                          /home/nixos/nix-config
                                          /home/nixos/invokeai
                                          /home/nixos/go
                                          /home/nixos/eclipse-workspace
                                          /home/nixos/codes
                                          /home/nixos/_sources
                                          /home/nixos/VirtualBox VMs
                                          /home/nixos/Videos
                                          /home/nixos/Templates
                                          /home/nixos/Pictures
                                          /home/nixos/Music
                                          /home/nixos/IdeaProjects
                                          /home/nixos/Games
                                          /home/nixos/GOG Games
                                          /home/nixos/Downloads
                                          /home/nixos/Documents
                                          /home/nixos/Desktop
                                          /home/nixos/BetterUniverse
                                          /home/nixos/Apps
                                          /home/nixos/AndroidStudioProjects
                                          /home/nixos/Android
                                          /home/nixos/.zoom
                                          /home/nixos/.wine
                                          /home/nixos/.winboat
                                          /home/nixos/.wakatime
                                          /home/nixos/.vscode-insiders
                                          /home/nixos/.vscode
                                          /home/nixos/.vmware
                                          /home/nixos/.var
                                          /home/nixos/.tldr
                                          /home/nixos/.thunderbird
                                          /home/nixos/.textgen
                                          /home/nixos/.terraform.d/plugin-cache
                                          /home/nixos/.steam
                                          /home/nixos/.ssh
                                          /home/nixos/.pulumi
                                          /home/nixos/.pki
                                          /home/nixos/.ollama
                                          /home/nixos/.npm
                                          /home/nixos/.net/devtunnel
                                          /home/nixos/.mozilla
                                          /home/nixos/.minecraft
                                          /home/nixos/.m2
                                          /home/nixos/.local/state/wireplumber
                                          /home/nixos/.local/state/opencode
                                          /home/nixos/.local/state/nvim
                                          /home/nixos/.local/state/nix/profiles
                                          /home/nixos/.local/state/home-manager
                                          /home/nixos/.local/state/Heroic
                                          /home/nixos/.local/share/zoxide
                                          /home/nixos/.local/share/zed
                                          /home/nixos/.local/share/wine/drive_c/users/nixos
                                          /home/nixos/.local/share/uv
                                          /home/nixos/.local/share/umu
                                          /home/nixos/.local/share/tiled
                                          /home/nixos/.local/share/remmina
                                          /home/nixos/.local/share/orca-slicer
                                          /home/nixos/.local/share/opencode
                                          /home/nixos/.local/share/nvim
                                          /home/nixos/.local/share/nix
                                          /home/nixos/.local/share/lutris
                                          /home/nixos/.local/share/krita
                                          /home/nixos/.local/share/keyrings
                                          /home/nixos/.local/share/k9s
                                          /home/nixos/.local/share/jupyter
                                          /home/nixos/.local/share/io.github.clash-verge-rev.clash-verge-rev
                                          /home/nixos/.local/share/gvfs-metadata
                                          /home/nixos/.local/share/flatpak
                                          /home/nixos/.local/share/feral-interactive
                                          /home/nixos/.local/share/direnv
                                          /home/nixos/.local/share/containers
                                          /home/nixos/.local/share/com.example.piliplus
                                          /home/nixos/.local/share/clash-verge
                                          /home/nixos/.local/share/bambu-studio
                                          /home/nixos/.local/share/authenticator
                                          /home/nixos/.local/share/atuin
                                          /home/nixos/.local/share/Trash
                                          /home/nixos/.local/share/TelegramDesktop
                                          /home/nixos/.local/share/Steam
                                          /home/nixos/.local/share/StardewValley
                                          /home/nixos/.local/share/Google
                                          /home/nixos/.local/share/GOG.com
                                          /home/nixos/.local/share/DBeaverData
                                          /home/nixos/.local/share/AyuGramDesktop
                                          /home/nixos/.local/bin
                                          /home/nixos/.lingma
                                          /home/nixos/.kube
                                          /home/nixos/.kimi-code
                                          /home/nixos/.jdks
                                          /home/nixos/.ipython
                                          /home/nixos/.gradle
                                          /home/nixos/.gnupg
                                          /home/nixos/.gnome
                                          /home/nixos/.docker
                                          /home/nixos/.cursor
                                          /home/nixos/.context7
                                          /home/nixos/.config/zed
                                          /home/nixos/.config/yuzu
                                          /home/nixos/.config/wechat-devtools
                                          /home/nixos/.config/vscode-sqltools
                                          /home/nixos/.config/uGet
                                          /home/nixos/.config/suyu
                                          /home/nixos/.config/sunshine
                                          /home/nixos/.config/remmina
                                          /home/nixos/.config/qv2ray
                                          /home/nixos/.config/pulse
                                          /home/nixos/.config/oray-tools
                                          /home/nixos/.config/opencode
                                          /home/nixos/.config/open-webui
                                          /home/nixos/.config/onlyoffice
                                          /home/nixos/.config/obs-studio
                                          /home/nixos/.config/nushell
                                          /home/nixos/.config/niri
                                          /home/nixos/.config/nekoray
                                          /home/nixos/.config/ncmpcpp
                                          /home/nixos/.config/mozc
                                          /home/nixos/.config/mihomo-party
                                          /home/nixos/.config/microsoft-edge
                                          /home/nixos/.config/lxc
                                          /home/nixos/.config/lutris
                                          /home/nixos/.config/libvirt
                                          /home/nixos/.config/libreoffice
                                          /home/nixos/.config/kdedefaults
                                          /home/nixos/.config/kdeconnect
                                          /home/nixos/.config/joplin
                                          /home/nixos/.config/io.hoppscotch.desktop
                                          /home/nixos/.config/icalingua
                                          /home/nixos/.config/heroic
                                          /home/nixos/.config/gsconnect
                                          /home/nixos/.config/google-chrome-unstable
                                          /home/nixos/.config/google-chrome
                                          /home/nixos/.config/go-musicfox
                                          /home/nixos/.config/gnome-boxes
                                          /home/nixos/.config/ghc
                                          /home/nixos/.config/gh
                                          /home/nixos/.config/gg
                                          /home/nixos/.config/gcloud
                                          /home/nixos/.config/freerdp
                                          /home/nixos/.config/flclash
                                          /home/nixos/.config/cursor
                                          /home/nixos/.config/clash-verge
                                          /home/nixos/.config/clash-nyanpasu
                                          /home/nixos/.config/clash
                                          /home/nixos/.config/chromium
                                          /home/nixos/.config/blender
                                          /home/nixos/.config/bilibili
                                          /home/nixos/.config/baidunetdisk
                                          /home/nixos/.config/anytype
                                          /home/nixos/.config/aichat
                                          /home/nixos/.config/agents
                                          /home/nixos/.config/aDrive
                                          /home/nixos/.config/VirtualBox
                                          /home/nixos/.config/Throne
                                          /home/nixos/.config/ServerBox
                                          /home/nixos/.config/Ryujinx
                                          /home/nixos/.config/QQ
                                          /home/nixos/.config/OrcaSlicer
                                          /home/nixos/.config/MuseScore
                                          /home/nixos/.config/Motrix
                                          /home/nixos/.config/Moonlight Game Streaming Project
                                          /home/nixos/.config/LaphaeLaicmd
                                          /home/nixos/.config/LDtk
                                          /home/nixos/.config/Kingsoft
                                          /home/nixos/.config/Joplin
                                          /home/nixos/.config/JetBrains
                                          /home/nixos/.config/Google
                                          /home/nixos/.config/Genymobile
                                          /home/nixos/.config/GIMP
                                          /home/nixos/.config/DingTalk
                                          /home/nixos/.config/Cursor
                                          /home/nixos/.config/Code - Insiders
                                          /home/nixos/.config/Code
                                          /home/nixos/.config/CherryStudio
                                          /home/nixos/.config/BambuStudio
                                          /home/nixos/.config/.cpolar
                                          /home/nixos/.config/.android
                                          /home/nixos/.conda
                                          /home/nixos/.codex
                                          /home/nixos/.claude
                                          /home/nixos/.cargo
                                          /home/nixos/.cache
                                          /home/nixos/.aws
                                          /home/nixos/.android
                                          /home/nixos/.aliyun
                                          /home/nixos/.agents
                                          /home/nixos/.Trash-1000
                                          /home/nixos/.Genymobile
                                          /etc/ssh
                                          /etc/secureboot
                                          /etc/secrets/android-keys
                                          /etc/nix/inputs
                                          /etc/netbird-homelab
                                          /etc/gnome-remote-desktop
                                          /etc/daed
                                          /etc/NetworkManager/system-connections
                                          /etc/agenix
                                          /nix/store
                                          /etc/machine-id
                                          /nix
                                          /persistent
                                          /
```
