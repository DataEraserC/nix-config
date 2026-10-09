# alist (openlist) - self-hosted file listing / management program.
#
# Moved out of the old desktop custom tree and wrapped as an options+config
# module: `modules.alist.enable` toggles the service, while the service
# account is defined UNCONDITIONALLY on purpose:
#
#   - agenix decrypts `alist-jwt` with owner=alist on every host with desktop
#     secrets (idols-ai, shoukei, both wsl hosts) and on aquamarine (webserver
#     secrets). The user must exist even where the service is disabled,
#     otherwise activation fails on chown.
#   - wsl_import.nix used to carry an ad-hoc alist stub for the same reason;
#     it is superseded by this definition.
#
# The uid is pinned to the value already live on idols-ai (999): dynamic ids
# (400-999) are only persisted per host in /var/lib/nixos/uid-map, which does
# not survive the wiped /var of an impermanence setup - re-allocating would
# orphan /var/lib/openlist and the decrypted secret. The gid stays dynamic:
# access is owner-based (uid), agenix uses mode 0700 owner=alist.
{
  config,
  lib,
  pkgs,
  nur-Moraxyc,
  ...
}:
let
  cfg = config.modules.alist;
in
{
  imports = [ nur-Moraxyc.nixosModules.alist ];

  options.modules.alist = {
    enable = lib.mkEnableOption "alist (openlist) file listing service";
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port alist listens on; the host that uses this module must set it (port registry network.services.alist.port).";
    };
    s3Port = lib.mkOption {
      type = lib.types.port;
      description = "alist settings.s3 listen port; the host that uses this module must set it (port registry network.services.alist.s3Port).";
    };
  };

  # NOTE: bare config attributes cannot coexist with an explicit `config` key,
  # so the unconditional account lives inside `config` alongside the mkIf'ed
  # service definition.
  config = {
    users.users.alist = {
      isSystemUser = true;
      group = "alist";
    };

    # The NUR module only declares this group while services.alist is enabled,
    # but the account above is unconditional - declare the group here so hosts
    # that only decrypt alist-jwt (wsl, shoukei) can still useradd -g alist.
    users.groups.alist = { };

    services.alist = lib.mkIf cfg.enable {
      enable = true;
      user = "alist";
      group = "alist";
      dataDir = "/var/lib/openlist/data";
      allowModify = true;
      package = pkgs.openlist;
      settings = {
        force = false;
        site_url = "";
        cdn = "";
        jwt_secret = {
          _secret = "/run/agenix/alist-jwt";
        };
        token_expires_in = 48;
        database = {
          type = "sqlite3";
          host = "";
          port = 0;
          user = "";
          password = "";
          name = "";
          db_file = "/var/lib/openlist/data/data.db";
          table_prefix = "x_";
          ssl_mode = "";
          dsn = "";
        };
        meilisearch = {
          host = "http://localhost:7700";
          api_key = "";
          index_prefix = "";
        };
        scheme = {
          address = "0.0.0.0";
          http_port = cfg.port;
          https_port = -1;
          force_https = false;
          cert_file = "";
          key_file = "";
          unix_file = "";
          unix_file_perm = "";
        };
        temp_dir = "/var/lib/openlist/data/temp";
        bleve_dir = "/var/lib/openlist/data/bleve";
        dist_dir = "";
        log = {
          enable = true;
          name = "/var/lib/openlist/data/log/log.log";
          max_size = 10;
          max_backups = 5;
          max_age = 28;
          compress = false;
        };
        delayed_start = 0;
        max_connections = 0;
        max_concurrency = 64;
        tls_insecure_skip_verify = true;
        tasks = {
          download = {
            workers = 5;
            max_retry = 1;
            task_persistent = false;
          };
          transfer = {
            workers = 5;
            max_retry = 2;
            task_persistent = false;
          };
          upload = {
            workers = 5;
            max_retry = 0;
            task_persistent = false;
          };
          copy = {
            workers = 5;
            max_retry = 2;
            task_persistent = false;
          };
          decompress = {
            workers = 5;
            max_retry = 2;
            task_persistent = false;
          };
          decompress_upload = {
            workers = 5;
            max_retry = 2;
            task_persistent = false;
          };
          allow_retry_canceled = false;
        };
        cors = {
          allow_origins = [
            "*"
          ];
          allow_methods = [
            "*"
          ];
          allow_headers = [
            "*"
          ];
        };
        s3 = {
          enable = false;
          port = cfg.s3Port;
          ssl = false;
        };
        ftp = {
          enable = false;
          listen = ":5221";
          find_pasv_port_attempts = 50;
          active_transfer_port_non_20 = false;
          idle_timeout = 900;
          connection_timeout = 30;
          disable_active_mode = false;
          default_transfer_binary = false;
          enable_active_conn_ip_check = true;
          enable_pasv_conn_ip_check = true;
        };
        sftp = {
          enable = false;
          listen = ":5222";
        };
      };
    };
  };
}
