# ===============================================================================
#
# AstrBot - multi-platform LLM chatbot / agent framework with a WebUI
#           (QQ, Telegram, WeCom, Feishu, DingTalk, Slack, Discord, ...),
#           https://github.com/AstrBotDevs/AstrBot
#
# Runs upstream's source tree directly under a Nix-managed Python 3.12 with a
# per-host virtualenv - no Docker, no Compose, no `uv tool install` outside the
# system. The unit, user, state layout, listen address and WebUI assets are all
# declared here; only the third-party Python wheels are resolved by `uv`.
#
# State layout - dataDir = /var/lib/astrbot (systemd StateDirectory):
#   /var/lib/astrbot/venv          virtualenv, built by astrbot-venv.service
#   /var/lib/astrbot/.cache/uv     uv download cache (kept across upgrades)
#   /var/lib/astrbot/.nix-source   store path the venv was built from (stamp)
#   /var/lib/astrbot/data/         ASTRBOT_ROOT/data: cmd_config.json, plugins,
#                                  plugin_data, knowledge_base, dist (WebUI)
#
# Why the virtualenv is provisioned at start instead of being a Nix derivation:
#   AstrBot's 65 direct requirements pull in packages nixpkgs does not carry
#   (aiocqhttp, qq-botpy, py-cord, wechatpy, silk-python, dingtalk-stream,
#   xinference-client, shipyard-*-sdk, markitdown-no-magika, python-ripgrep, ...);
#   several only ship binary wheels and upstream keeps no lock file, so every
#   version bound floats. A buildPythonApplication port would need a hand-written
#   derivation per missing package plus overrides for each floating bound, and it
#   would break again the next time upstream adds a dependency. Nix therefore owns
#   the source pin, the WebUI bundle, the interpreter, uv and the service
#   plumbing, and `uv pip install -r requirements.txt` fills the venv once per
#   source version. Consequences, both documented in WORKAROUNDS_downstream.md
#   (DS-013): the first start needs network access, and the resolved wheel set is
#   not bit-for-bit reproducible - rerun provisioning after wiping the venv if it
#   ever drifts.
#
# WebUI assets: the git tree carries no built dashboard, so the release asset
# AstrBot-v<version>-dashboard.zip is fetched with a pinned hash and unpacked as
# data/dist, which AstrBot prefers over a (here absent) bundled dist. The asset
# is built from the same tag, so its assets/version matches core's VERSION.
#
# ASTRBOT_CLI=1 disables the in-app core updater - it would try to rewrite the
# read-only store tree. Upgrade by bumping `version` plus `srcHash` and
# `dashboardHash` below, then redeploy; the stamp mismatch rebuilds the venv.
#
# The listen address is owned here: every start rewrites dashboard.host and
# dashboard.port in data/cmd_config.json, while every other setting stays
# WebUI-managed (AstrBot merges its defaults into the stored config itself).
# IM adapters that open their own port (OneBot v11, webhook callbacks, ...) are
# configured in the WebUI and need that port allowed by the host firewall - on
# this repo's hosts the LAN and overlays are trusted wholesale, so only
# `openFirewall` on other hosts is a concern.
#
# Check service status
#   systemctl status astrbot astrbot-venv
# Check logs (first deploy logs the generated dashboard password once)
#   journalctl -u astrbot --since "2 minutes ago"
# Rebuild the python environment from scratch
#   sudo rm -rf /var/lib/astrbot/venv /var/lib/astrbot/.nix-source
#   systemctl restart astrbot
#
# Two things the environment below exists for, both verified on the pinned
# version: pip's manylinux wheels link against the host's libstdc++/zlib, which
# NixOS has no /lib for (hence LD_LIBRARY_PATH - without it `import numpy`
# dies with "libstdc++.so.6: cannot open shared object file"), and faiss-cpu
# spawns OpenMP threads at import, so on a host with a tight pids/threads limit
# (`import faiss` segfaulting, knowledge base unusable) add
# OMP_NUM_THREADS=1 through `environment`.
# ===============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.astrbot;

  version = "4.29.3";
  # Bump together with `version`: `nix store prefetch-file --unpack <tarball>`
  # for srcHash, plain `nix store prefetch-file <zip>` for dashboardHash.
  srcHash = "sha256-cpdaLct3OBVF3lJW9rGQBQz5O0dE0z7+pz1mWGHON9I=";
  dashboardHash = "sha256-oJ9WDEFAuTAYD2OkkpyIXagOJPubvaVmGXJ70l6YWhE=";

  dataDir = "/var/lib/astrbot";

  src = pkgs.fetchFromGitHub {
    owner = "AstrBotDevs";
    repo = "AstrBot";
    tag = "v${version}";
    hash = srcHash;
  };

  # Prebuilt WebUI bundle from the release page; unpacked so the derivation
  # exposes `dist/` and can be copied to <dataDir>/data/dist.
  dashboard =
    pkgs.runCommand "astrbot-dashboard-${version}" { nativeBuildInputs = [ pkgs.unzip ]; }
      ''
        mkdir -p $out
        unzip -q ${
          pkgs.fetchurl {
            url = "https://github.com/AstrBotDevs/AstrBot/releases/download/v${version}/AstrBot-v${version}-dashboard.zip";
            hash = dashboardHash;
          }
        } -d $out
      '';

  # Runtime tools AstrBot shells out to: ffmpeg for the silk/voice pipeline,
  # ripgrep and node for plugins and the agent sandbox, git for plugin installs.
  runtimePackages = [
    pkgs.coreutils
    pkgs.bash
    pkgs.ffmpeg
    pkgs.git
    pkgs.nodejs
    pkgs.ripgrep
    pkgs.uv
  ];

  # manylinux wheels dlopen libstdc++/libgomp (faiss-cpu) and zlib (pandas,
  # pillow) from the host instead of bundling them, and NixOS has no /lib;
  # export the Nix copies so `import faiss` and friends resolve.
  wheelLibraryPath = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
  ];

  # One-shot provisioning: venv + requirements + WebUI bundle, keyed by the
  # source store path so an upgrade (or a wiped venv) reinstalls exactly once.
  provision = pkgs.writeShellApplication {
    name = "astrbot-provision";
    runtimeInputs = runtimePackages ++ [
      cfg.python
      pkgs.gcc
      pkgs.pkg-config
    ];
    text = ''
      state=${lib.escapeShellArg dataDir}
      venv="$state/venv"
      stamp="$state/.nix-source"
      target=${lib.escapeShellArg "${src}"}

      export HOME="$state"
      export UV_CACHE_DIR="$state/.cache/uv"
      # Never let uv fetch its own interpreter: the version is Nix's.
      export UV_PYTHON_DOWNLOADS=never
      export UV_LINK_MODE=copy
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      export LD_LIBRARY_PATH=${wheelLibraryPath}
      ${lib.optionalString (cfg.packageIndex != null) ''
        export UV_DEFAULT_INDEX=${lib.escapeShellArg cfg.packageIndex}
      ''}

      mkdir -p "$state/data" "$UV_CACHE_DIR"

      if [[ -x "$venv/bin/python" && -f "$stamp" ]] && [[ "$(cat "$stamp")" == "$target" ]]; then
        echo "astrbot: environment for $target already provisioned"
        exit 0
      fi

      echo "astrbot: provisioning python environment from $target"
      if [[ ! -x "$venv/bin/python" ]]; then
        uv venv --python ${cfg.python}/bin/python3 "$venv"
      fi

      # requirements.txt holds ranges (no upstream lock file), so this resolves
      # at first start; pip itself is one of the requirements.
      uv pip install --python "$venv/bin/python" -r "$target/requirements.txt"

      # Extras the Docker image installs by hand: a SOCKS transport for
      # httpx[socks], the silk/pilk voice codec, and uv for the plugin
      # installer's newer path.
      uv pip install --python "$venv/bin/python" socksio uv pilk

      # The WebUI bundle is versioned with core, so replace it wholesale. Store
      # files arrive read-only (0555/0444), so grant the service user write
      # access first - otherwise the rm below fails on a read-only directory
      # and AstrBot could not update its own dashboard either.
      if [[ -d "$state/data/dist" ]]; then
        chmod -R u+w "$state/data/dist"
        rm -rf "$state/data/dist"
      fi
      cp -r ${dashboard}/dist "$state/data/dist"
      chmod -R u+w "$state/data/dist"

      printf '%s\n' "$target" > "$stamp"
      echo "astrbot: environment ready"
    '';
  };

  # Declarative listen address: AstrBot only exposes dashboard.host/port through
  # its JSON config, so seed/patch that file (merging defaults is AstrBot's job)
  # before every start. Other keys are left untouched.
  seedConfig = pkgs.writeShellApplication {
    name = "astrbot-seed-config";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      conf=${lib.escapeShellArg "${dataDir}/data/cmd_config.json"}
      mkdir -p "$(dirname "$conf")"
      if [[ ! -s "$conf" ]]; then
        printf '{}\n' > "$conf"
      fi

      tmp="$(mktemp "$conf.XXXXXX")"
      jq --arg host ${lib.escapeShellArg cfg.host} \
        --argjson port ${toString cfg.port} \
        '.dashboard = ((.dashboard // {}) + {host: $host, port: $port})' \
        "$conf" > "$tmp"
      mv "$tmp" "$conf"
    '';
  };
in
{
  options.modules.astrbot = {
    enable = lib.mkEnableOption "AstrBot multi-platform LLM chatbot (native, no Docker)";

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port the AstrBot dashboard/WebUI listens on; the host that uses this module must set it (port registry myvars.networking.services.astrbot.hosts.<machine>.port).";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = ''
        Dashboard bind address written to dashboard.host on every start. The
        default listens on all interfaces; the shared host firewall only trusts
        the LAN and the overlay interfaces, so this is reachable there unless
        the host firewall says otherwise.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "astrbot";
      description = ''
        Account astrbot.service and astrbot-venv.service run as. This module
        only creates the default `astrbot` account; any other value is assumed
        to exist already (a normal user, or one declared elsewhere), so no
        account is generated for it. Switching after the first start needs the
        state directory handed over: `chown -R <user>:<group> /var/lib/astrbot`.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "astrbot";
      description = ''
        Primary group of the service account. Created by this module only when
        left at the default name; otherwise it must already exist. Keep it
        group-readable if other accounts need to read the venv or the WebUI
        bundle: StateDirectoryMode gives the group r-x.
      '';
    };

    python = lib.mkOption {
      type = lib.types.package;
      default = pkgs.python312;
      description = "Python interpreter used to build the virtualenv (upstream requires >= 3.12).";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        ASTRBOT_DASHBOARD_INITIAL_PASSWORD = "change-me";
      };
      description = ''
        Extra environment variables for astrbot.service, e.g. the initial
        dashboard password (ASTRBOT_DASHBOARD_INITIAL_PASSWORD, honoured on the
        first deploy only) or proxy variables. Use environmentFile for secrets.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional EnvironmentFile for astrbot.service (agenix secret path, kept out of the store-written unit).";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages on astrbot.service's PATH, for plugins that shell out to system tools.";
    };

    packageIndex = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://pypi.tuna.tsinghua.edu.cn/simple";
      description = ''
        Alternative Python package index for the provisioning step (passed as
        uv's UV_DEFAULT_INDEX). PyPI from mainland China is slow enough that the
        first start can hit the provisioning timeout, so a mirror helps there.
        Changing it does not re-provision by itself: wipe the venv and the stamp
        (see the header) and restart.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open `port` in the host firewall for every interface. Note the shared
        firewall module (modules/nixos/base/networking/firewall.nix) forces
        allowedTCPPorts to [ ] and trusts the LAN/overlays by source, so this
        only matters on hosts that do not import it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Both are created only for the default names: a custom user/group is
    # expected to come from the rest of the configuration, and managing it here
    # would reset its attributes (isSystemUser, home, ...).
    users.groups = lib.mkIf (cfg.group == "astrbot") {
      astrbot = { };
    };
    users.users = lib.mkIf (cfg.user == "astrbot") {
      ${cfg.user} = {
        isSystemUser = true;
        inherit (cfg) group;
        home = dataDir;
        description = "AstrBot chatbot service";
      };
    };

    systemd.services.astrbot-venv = {
      description = "Provision the AstrBot virtualenv from the pinned source";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = "astrbot";
        StateDirectoryMode = "0750";
        WorkingDirectory = dataDir;
        ExecStart = "${provision}/bin/astrbot-provision";
        # First run downloads ~1GB of wheels.
        TimeoutStartSec = "1800";
        # No Restart: a failed install must surface in `systemctl status`, and a
        # restart loop would hammer PyPI. Restart astrbot after fixing the cause.
        Restart = "no";
      };
    };

    systemd.services.astrbot = {
      description = "AstrBot multi-platform LLM chatbot";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "astrbot-venv.service"
      ];
      requires = [ "astrbot-venv.service" ];

      # `path` entries get /bin appended, so pass the venv root, not venv/bin.
      path = [ "${dataDir}/venv" ] ++ runtimePackages ++ cfg.extraPackages;

      environment = {
        ASTRBOT_ROOT = dataDir;
        # Declares a CLI-managed install: the in-app core updater refuses to run
        # instead of writing into the read-only store tree.
        ASTRBOT_CLI = "1";
        HOME = dataDir;
        LD_LIBRARY_PATH = wheelLibraryPath;
        PYTHONPATH = "${src}";
        PYTHONUNBUFFERED = "1";
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        XDG_CACHE_HOME = "${dataDir}/.cache";
      }
      // cfg.environment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = "astrbot";
        StateDirectoryMode = "0750";
        WorkingDirectory = dataDir;
        ExecStartPre = "${seedConfig}/bin/astrbot-seed-config";
        ExecStart = "${dataDir}/venv/bin/python ${src}/main.py";
        Restart = "on-failure";
        RestartSec = 5;

        # AstrBot only writes under its own state directory; everything else
        # (store source, /etc, /home) stays read-only.
        NoNewPrivileges = true;
        ProtectSystem = "full";
        ProtectHome = true;
        # Left at the systemd default: get_astrbot_system_tmp_path() puts the
        # agent sandbox's scratch under /tmp/.astrbot, which is also where the
        # tools it spawns look for it.
        PrivateTmp = false;
      }
      // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
