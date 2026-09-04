# ===============================================================================
#
# Periodically push a host liveness heartbeat via ntfy.
#
# The heartbeat message is rendered as markdown by the ntfy app, it contains:
#   - host alive status: hostname / uptime / ISO8601 timestamp
#   - network info: per-interface IPv4/IPv6 and public IP
#   - cpolar tunnel status(optional, skipped gracefully if credentials missing)
#
# Notification metadata follows the repo-wide ntfy message spec:
#   title "<host> · <event>", tags -> emoji, priority by importance.
#   this service: title "<host> · heartbeat", tags "computer", priority "min".
#
# Architecture note: the script's logic lives in ../scripts/host-heartbeat-notify.sh
# as a plain shell file(no nix interpolation inside), all config-dependent values
# are injected into the systemd unit via `environment`. This keeps the script
# free of nix indented-string escaping/indentation pitfalls and easy to test.
#
# Secrets are sourced at runtime from environment files configurable via:
#   - ntfyTopicFile(default /etc/agenix/ntfy-topic.env, provides $NTFY_TOPIC)
#   - cpolarEnvFile(default /etc/agenix/cpolar-status.env)
# ntfy publish failures are logged only, they never fail this service.
#
# Check logs:
#   journalctl -u host-heartbeat --since "1 hour ago"
# Check timer:
#   systemctl list-timers host-heartbeat.timer
{
  config,
  lib,
  pkgs,
  cpolar-status,
  ...
}:
let
  cfg = config.modules.host-heartbeat;

  cpolarStatus = cpolar-status.packages.${pkgs.system}.default;

  script = pkgs.writeShellScript "host-heartbeat-notify" (
    builtins.readFile ../scripts/host-heartbeat-notify.sh
  );
in
{
  options.modules.host-heartbeat = {
    enable = lib.mkEnableOption ''
      periodic host liveness heartbeat pushed to a ntfy server(topic from agenix secrets)
    '';

    hostName = lib.mkOption {
      type = lib.types.str;
      description = ''
        Hostname shown in the heartbeat message and the ntfy title.
        Set it explicitly from the importing host(keeps this module decoupled
        from other modules' configuration).
      '';
    };

    username = lib.mkOption {
      type = lib.types.str;
      description = ''
        Primary username shown in the heartbeat message.
        Set it explicitly from the importing host.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "30min";
      description = ''
        Time between heartbeats, as a systemd time span(see systemd.time(7)).
        Applied via OnUnitActiveSec of the systemd timer.
      '';
    };

    includeCpolarStatus = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Include cpolar tunnel status in the heartbeat.
        Requires the credentials file configured by cpolarEnvFile; the section is
        skipped gracefully when it is missing or unreadable instead of failing.
      '';
    };

    ntfyTopicFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/agenix/ntfy-topic.env";
      description = ''
        Environment file sourced at runtime to obtain the ntfy topic.
        Expected content: NTFY_TOPIC=<topic>. When the file is missing or the
        variable is empty, the heartbeat is skipped with a log message.
      '';
    };

    cpolarEnvFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/agenix/cpolar-status.env";
      description = ''
        Environment file providing the cpolar credentials(CPOLAR_USERNAME and
        CPOLAR_PASSWORD), used only when includeCpolarStatus is enabled.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.timers.host-heartbeat = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "host-heartbeat.service";
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.interval;
      };
    };

    systemd.services.host-heartbeat = {
      description = "Push host liveness heartbeat via ntfy";
      after = [ "network-online.target" ] ++ lib.optionals cfg.includeCpolarStatus [ "cpolar.service" ];
      wants = [ "network-online.target" ] ++ lib.optionals cfg.includeCpolarStatus [ "cpolar.service" ];
      path = with pkgs; [
        bash
        procps
        coreutils
        gnugrep
        gnused
        iproute2
        curl
        ntfy-sh
      ];
      # all config-dependent values are injected as environment variables,
      # so that the shell script stays decoupled from nix evaluation.
      environment = {
        HOST_NAME = cfg.hostName;
        USER_NAME = cfg.username;
        NTFY_TOPIC_FILE = toString cfg.ntfyTopicFile;
      }
      // lib.optionalAttrs cfg.includeCpolarStatus {
        CPOLAR_CREDENTIALS_FILE = toString cfg.cpolarEnvFile;
        CPOLAR_STATUS_BIN = toString (lib.getExe cpolarStatus);
      };
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = script;
      };
    };
  };
}
