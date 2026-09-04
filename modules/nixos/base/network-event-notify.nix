# ===============================================================================
#
# NetworkManager dispatcher hook(shared): push a network event notification via
# ntfy(markdown) on up/down/vpn-up/vpn-down, and re-authenticate the tp_link
# router(anonymous host) on up/vpn-up events.
#
# Notification metadata follows the repo-wide ntfy message spec:
#   title "<host> · network <status>", tags globe_with_meridians(up) /
#   warning(down), priority default(high for down), markdown body.
#
# Architecture note: the script's logic lives in
# ../scripts/network-event-notify.sh as a plain shell file(no nix interpolation
# inside); config-dependent values are injected by a thin generated wrapper via
# environment variables, then exec'd with the original NM arguments.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.network-event-notify;

  script = pkgs.writeShellScript "network-event-notify" (
    builtins.readFile ../scripts/network-event-notify.sh
  );

  # Thin NM dispatcher entry: injects environment, then execs the shared script
  # with the original arguments(interface & status).
  wrapper = pkgs.writeShellScript "nm-dispatcher-hook" ''
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.iproute2
        pkgs.curl
        pkgs.ntfy-sh
        pkgs.libnotify
      ]
    }''${PATH:+:$PATH}"
    export HOST_NAME="${cfg.hostName}"
    export NTFY_TOPIC_FILE="${toString cfg.ntfyTopicFile}"
    exec ${script} "$@"
  '';
in
{
  options.modules.network-event-notify = {
    enable = lib.mkEnableOption ''
      ntfy network event notifications via the NetworkManager dispatcher
    '';

    hostName = lib.mkOption {
      type = lib.types.str;
      description = ''
        Hostname shown in the notification message and title.
        Set it explicitly from the importing host(keeps this module decoupled
        from other modules' configuration).
      '';
    };

    ntfyTopicFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/agenix/ntfy-topic.env";
      description = ''
        Environment file sourced at runtime to obtain the ntfy topic.
        Expected content: NTFY_TOPIC=<topic>. When the file is missing or the
        variable is empty, the notification is skipped with a log message.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager.dispatcherScripts = [
      {
        source = wrapper;
        type = "basic";
      }
    ];
  };
}
