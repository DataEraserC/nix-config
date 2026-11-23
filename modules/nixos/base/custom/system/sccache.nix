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
    # The pinned account comes from hosts/service-user-ids.nix. The server uses
    # nixbld for cache ownership, but auto-allocated build UIDs have no
    # supplementary groups and reach only the world-writable Unix socket.
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
        RuntimeDirectoryMode = "0711";
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

    # sccache 0.19 creates its UDS as 0750. Nix's auto-allocated build UIDs
    # have no supplementary groups, so each new socket must be 0666; the 0711
    # runtime directory prevents listing, and the cache directory stays 0770.
    systemd.paths.sccache-socket-permissions = {
      description = "Watch for the sccache Unix socket";
      wantedBy = [ "multi-user.target" ];
      before = [ "sccache.service" ];
      pathConfig.PathChanged = socketDir;
    };

    systemd.services.sccache-socket-permissions = {
      description = "Grant Nix builders access to the sccache Unix socket";
      serviceConfig = {
        Type = "oneshot";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ socketDir ];
      };
      script = ''
        if [[ -S ${socketPath} ]] && [[ "$(stat -c %a ${socketPath})" != 666 ]]; then
          chmod 0666 ${socketPath}
        fi
      '';
    };
  };
}
