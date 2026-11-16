# Our preservation entries.
#
# The sibling `preservation.nix` keeps the base list; these additions live here
# so base-list changes never conflict with them. Both modules set the same list
# options and the module system concatenates them.
{
  config,
  myvars,
  ...
}:
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

      # alist (openlist)
      #
      # The service writes /var/lib/openlist/data as alist. Declare the owner
      # explicitly and converge it recursively below; otherwise a UID change
      # leaves data/ owned by the old numeric id and the pre-start's
      # `cp config.json` fails with EACCES before the service can start.
      {
        directory = "/var/lib/openlist";
        user = "alist";
        group = "alist";
        mode = "0755";
      }
      # daed
      "/etc/daed/"

      # cliproxyapi (generated config.yaml, management key and auth/provider files)
      #
      # Declare the owner explicitly. preservation turns each entry into a
      # tmpfiles `d` rule, and the default owner is root:root. That rule also
      # runs from systemd-tmpfiles-resetup during a rebuild, while the service
      # is already running, so an undeclared owner revokes its access to the
      # state directory.
      {
        directory = "/var/lib/cliproxyapi";
        user = "cliproxyapi";
        group = "cliproxyapi";
        mode = "0700";
      }

      # new-api (database)
      {
        directory = "/var/lib/new-api";
        user = "new-api";
        group = "new-api";
        mode = "0700";
      }

      # m365-copilot2api (accounts, tokens, sessions, API keys, settings)
      {
        directory = "/var/lib/m365-copilot2api";
        user = "m365-copilot2api";
        group = "m365-copilot2api";
        mode = "0700";
      }

      # meoo2api (state.json with accounts, project keys, client API keys,
      # usage log and settings)
      {
        directory = "/var/lib/meoo2api";
        user = "meoo2api";
        group = "meoo2api";
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

      # agent2api (SQLite database with accounts and API keys, credential
      # encryption key, request logs)
      {
        directory = "/var/lib/agent2api";
        mode = "0700";
      }

      # our-free-model-standalone (account pool, credentials, settings, API key)
      {
        directory = "/var/lib/our-free-model-standalone";
        mode = "0700";
      }

      # webmux (config.toml with the access token, launch configs, runtime
      # records). The unit runs as the login user, so the tmpfiles rule must
      # carry that owner instead of the preservation default root:root.
      {
        directory = "/var/lib/webmux";
        user = "${username}";
        group = "users";
        mode = "0700";
      }

      # acb-issue-service (SQLite issue database). The unit is pinned to the
      # acb-issue account: a DynamicUser uid is not stable across reboots, so
      # the preserved directory could not keep a readable owner.
      {
        directory = "/var/lib/acb-issue";
        user = "acb-issue";
        group = "acb-issue";
        mode = "0750";
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

      # gnome-remote-desktop runs as a system service under its own account
      # (User=gnome-remote-desktop). Its package ships the matching tmpfiles
      # rules: /var/lib 0700, /etc 0755, both gnome-remote-desktop:gnome-remote-desktop.
      {
        directory = "/var/lib/gnome-remote-desktop";
        user = "gnome-remote-desktop";
        group = "gnome-remote-desktop";
        mode = "0700";
      }
      {
        directory = "/etc/gnome-remote-desktop";
        user = "gnome-remote-desktop";
        group = "gnome-remote-desktop";
        mode = "0755";
      }

      # shared sunshine identity data (see hosts/idols-ai/sunshine.nix)
      {
        directory = "/var/lib/sunshine";
        user = "root";
        group = "sunshine";
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
        ".local/share/acb"
        # bridge/dsh runtime logs (StateDirectory alone does not survive reboot)
        ".local/state/acb"

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

  # Converge ownership recursively for the service state directories.
  #
  # The preservation `d` rules above only manage the top-level directory. Files
  # created under an older numeric uid/gid keep their stale owner, and systemd
  # skips StateDirectory's recursive ownership fix when the top-level directory
  # already matches User=/Group=. `Z` runs before the services start and on
  # every systemd-tmpfiles-resetup, so a UID/GID reallocation or a restored
  # /persistent never leaves an unreadable database behind. The mode field is
  # left unset so existing file modes, including the SQLite database's 0600,
  # are preserved.
  #
  # The rules are unconditional so every host generates the same Z set and the
  # file stays byte-identical across the three hosts. `Z` on a missing path is
  # a no-op, and all referenced accounts exist on every host through the
  # shared service-id table.
  systemd.tmpfiles.rules = [
    "Z /var/lib/cliproxyapi - cliproxyapi cliproxyapi - -"
    "Z /var/lib/openlist - alist alist - -"
    "Z /var/lib/m365-copilot2api - m365-copilot2api m365-copilot2api - -"
    "Z /var/lib/new-api - new-api new-api - -"
    # Sunshine state is shared by the login and greeter instances. Only the
    # group has to be converged; owner and modes stay as each instance wrote
    # them.
    "Z /var/lib/sunshine - - sunshine - -"
    "Z /var/lib/gnome-remote-desktop - gnome-remote-desktop gnome-remote-desktop - -"
    "Z /etc/gnome-remote-desktop - gnome-remote-desktop gnome-remote-desktop - -"
  ];
}
