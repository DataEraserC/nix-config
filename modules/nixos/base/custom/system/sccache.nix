{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.sccache;
  socketDir = "/run/sccache";
  socketPath = "${socketDir}/sccache.sock";
in
{
  options.modules.sccache = {
    enable = lib.mkEnableOption "a persistent compiler cache for local Nix builds";

    package = lib.mkPackageOption pkgs "sccache" { };

    cacheSize = lib.mkOption {
      type = lib.types.str;
      default = "32G";
      description = "Maximum size of the local sccache artifact cache.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The pinned account comes from hosts/service-user-ids.nix. Build users need
    # group access to the Unix socket; the server itself stays unprivileged.
    users.users.sccache.extraGroups = [ "nixbld" ];

    environment.systemPackages = [ cfg.package ];

    # The socket is optional so nix-daemon can start before this service. Only
    # the socket directory enters build sandboxes; the cache directory does not.
    nix.settings.extra-sandbox-paths = [ "${socketDir}?" ];

    systemd.services.sccache = {
      description = "Shared compiler cache for local Nix builds";
      wantedBy = [ "multi-user.target" ];

      environment = {
        SCCACHE_DIR = "/var/cache/sccache";
        SCCACHE_CACHE_SIZE = cfg.cacheSize;
        SCCACHE_SERVER_UDS = socketPath;
        SCCACHE_START_SERVER = "1";
        SCCACHE_NO_DAEMON = "1";
        SCCACHE_IDLE_TIMEOUT = "0";
        SCCACHE_LOCAL_RW_MODE = "READ_WRITE";
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.getExe cfg.package;
        User = "sccache";
        Group = "nixbld";
        UMask = "0007";

        RuntimeDirectory = "sccache";
        RuntimeDirectoryMode = "0770";
        CacheDirectory = "sccache";
        CacheDirectoryMode = "0770";

        Restart = "on-failure";
        RestartSec = "2s";

        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
      };
    };

    # sccache 0.19 creates its UDS as 0750 even with a group-friendly umask.
    # Watch the runtime directory before the server starts and repair each new
    # socket without polling. The launcher falls back until this has happened.
    systemd.paths.sccache-socket-permissions = {
      description = "Watch for the sccache Unix socket";
      wantedBy = [ "multi-user.target" ];
      before = [ "sccache.service" ];
      pathConfig.PathChanged = socketDir;
    };

    systemd.services.sccache-socket-permissions = {
      description = "Grant nixbld access to the sccache Unix socket";
      serviceConfig = {
        Type = "oneshot";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
      script = ''
        if [[ -S ${socketPath} ]]; then
          chgrp nixbld ${socketPath}
          chmod 0770 ${socketPath}
        fi
      '';
    };
  };
}
