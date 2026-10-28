# Our preservation entries.
#
# The sibling `preservation.nix` keeps the base list; these additions live here
# so base-list changes never conflict with them. Both modules set the same list
# options and the module system concatenates them.
{ config, myvars, ... }:
let
  inherit (myvars) username;
in
{
  preservation.preserveAt."/persistent" = {
    directories = [

      # upstream keeps this commented out; we enable it here so the base file
      # stays byte-identical to upstream
      "/var/lib/waydroid"

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

      # our-free-model-standalone (account pool, credentials, settings, API key)
      {
        directory = "/var/lib/our-free-model-standalone";
        mode = "0700";
      }

      # astrbot (venv, uv cache, cmd_config.json, plugins, plugin_data,
      # knowledge base, WebUI dist). Keeping the venv here means an AstrBot
      # upgrade only re-resolves the wheels instead of reinstalling ~1GB; delete
      # it (and .nix-source) to force a clean rebuild.
      "/var/lib/astrbot"

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

    users.${username} = {
      directories = [
        "Templates"

        ".gnome"
        # rclone configuration and credentials
        ".config/rclone"

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
        ".dsh"
        ".dsh-tui"
        # opencode2dsh bridge: agent-config.json, agent-token.txt (0600, the
        # loopback bridge token), adapter-status.json, the models.dev price
        # cache and singbox/singbox-config.json (subscription nodes).
        ".opencode2dsh"

        # pi coding agent (sessions under ~/.pi/agent/sessions)
        ".pi"

        ".config/lutris"
        ".local/share/lutris"
        ".local/share/wine/drive_c/users/${username}"
        ".local/share/tiled"
        ".local/share/qq-bridge"

        # ======================================
        # Instant Messaging
        # ======================================
        ".config/QQ"

        ".local/share/TelegramDesktop"
        ".local/share/AyuGramDesktop"
        ".config/google-chrome-unstable"

        # Mayuri Spec

        # ======================================
        # Apps
        # ======================================

        # Clash Verge Rev
        ".local/share/io.github.clash-verge-rev.clash-verge-rev"
        ".local/share/clash-verge"

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
        # comfyui user dir (custom_nodes, input); created by pkgs.comfyui on first run
        ".local/share/comfyui"
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
      ]
      # The multi-instance store and every app's state paths come from the one
      # table in modules/nixos/base/custom/multi-instance, so a program added
      # there is preserved here too.
      ++ config.modules.multi-instance.preserveDirectories;
    };
  };
}
