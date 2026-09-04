# ===============================================================================
#
# One-shot after boot: report cpolar tunnel status via ntfy(markdown) and a
# desktop notification(if an active graphical session exists).
#
# Notification metadata follows the repo-wide ntfy message spec:
#   title "<host> · cpolar tunnels", tags "satellite_antenna", priority "low".
#
# Architecture note: the script's logic lives in ./scripts/cpolar-status-notify.sh
# as a plain shell file(no nix interpolation inside), all config-dependent values
# are injected into the systemd unit via `environment`.
#
# Secrets are sourced at runtime from environment files configurable via:
#   - credentialsFile(default /etc/agenix/cpolar-status.env)
#   - ntfyTopicFile(default /etc/agenix/ntfy-topic.env, provides $NTFY_TOPIC)
# Missing credentials are logged and skipped gracefully; a failing cpolar-status
# command exits non-zero so systemd(Restart = on-failure) retries it.
#
# Check logs:
#   journalctl -u cpolar-status --since "10 minutes ago"
{
  config,
  lib,
  pkgs,
  cpolar-status,
  ...
}:
let
  cfg = config.modules.cpolar-status;

  cpolarStatus = cpolar-status.packages.${pkgs.system}.default;

  script = pkgs.writeShellScript "cpolar-status-boot-notify" (
    builtins.readFile ./scripts/cpolar-status-notify.sh
  );
in
{
  options.modules.cpolar-status = {
    enable = lib.mkEnableOption ''
      one-shot cpolar tunnel status report(via ntfy and desktop notification) after boot
    '';

    hostName = lib.mkOption {
      type = lib.types.str;
      description = ''
        Hostname shown in the report message and the ntfy title.
        Set it explicitly from the importing host(keeps this module decoupled
        from other modules' configuration).
      '';
    };

    username = lib.mkOption {
      type = lib.types.str;
      description = ''
        Primary username, used to look up the active graphical session for
        notify-send. Set it explicitly from the importing host.
      '';
    };

    credentialsFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/agenix/cpolar-status.env";
      description = ''
        Environment file providing the cpolar credentials(CPOLAR_USERNAME and
        CPOLAR_PASSWORD). When it is missing or unreadable, the report is
        skipped gracefully with a log message.
      '';
    };

    ntfyTopicFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/agenix/ntfy-topic.env";
      description = ''
        Environment file sourced at runtime to obtain the ntfy topic.
        Expected content: NTFY_TOPIC=<topic>.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.timers.cpolar-status = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "cpolar-status.service";
        OnBootSec = "120s";
      };
    };

    systemd.services.cpolar-status = {
      description = "Report cpolar tunnel status after boot via ntfy and notify-send";
      after = [
        "network-online.target"
        "cpolar.service"
      ];
      wants = [ "network-online.target" ];
      path = with pkgs; [
        bash
        coreutils
        procps
        gnugrep
        gnused
        util-linux
        libnotify
        ntfy-sh
      ];
      # all config-dependent values are injected as environment variables,
      # so that the shell script stays decoupled from nix evaluation.
      environment = {
        HOST_NAME = cfg.hostName;
        USER_NAME = cfg.username;
        NTFY_TOPIC_FILE = toString cfg.ntfyTopicFile;
        CPOLAR_CREDENTIALS_FILE = toString cfg.credentialsFile;
        CPOLAR_STATUS_BIN = toString (lib.getExe cpolarStatus);
      };
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = script;
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
  };
}
