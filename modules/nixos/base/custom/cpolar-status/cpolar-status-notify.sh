#!/usr/bin/env bash
# One-shot after boot: report cpolar tunnel status via ntfy(markdown) and a
# desktop notification(if an active graphical session exists).
#
# All inputs are injected by the systemd unit as environment variables, so this
# script stays free of any nix/config coupling:
#   HOST_NAME                target hostname, e.g. ai
#   USER_NAME                primary username, e.g. nixos(used by notify-send)
#   NTFY_TOPIC_FILE          env-file providing $NTFY_TOPIC(required)
#   CPOLAR_CREDENTIALS_FILE  env-file providing CPOLAR_USERNAME/CPOLAR_PASSWORD
#   CPOLAR_STATUS_BIN        absolute path to the cpolar-status binary
#
# Missing credentials/topic are logged and skipped gracefully(exit 0); a failing
# cpolar-status command exits non-zero so systemd(Restart = on-failure) retries.
#
# Message spec(repo-wide): title "<host> · cpolar tunnels",
# tags "satellite_antenna", priority "low", markdown body.
set -uo pipefail

credentials_file="${CPOLAR_CREDENTIALS_FILE:?CPOLAR_CREDENTIALS_FILE must be set}"
if [ -f "$credentials_file" ]; then
  . "$credentials_file" 2>/dev/null
fi
if [ -z "${CPOLAR_USERNAME:-}" ] || [ -z "${CPOLAR_PASSWORD:-}" ]; then
  echo "cpolar credentials unavailable($credentials_file missing/unreadable or empty), skip report" >&2
  exit 0
fi

topic_file="${NTFY_TOPIC_FILE:?NTFY_TOPIC_FILE must be set}"
if [ -f "$topic_file" ]; then
  . "$topic_file"
fi
if [ -z "${NTFY_TOPIC:-}" ]; then
  echo "ntfy topic unavailable($topic_file missing or NTFY_TOPIC empty), skip report" >&2
  exit 0
fi

OUTPUT="$("$CPOLAR_STATUS_BIN" --username "$CPOLAR_USERNAME" --password "$CPOLAR_PASSWORD")" || {
  echo "cpolar-status failed" >&2
  exit 1
}

TUNNELS_MD="$(printf '%s\n' "$OUTPUT" | sed 's/^/- /')"

MSG="**Host** ${HOST_NAME}
**Tunnels (cpolar)**
$TUNNELS_MD

**Time** $(date --iso-8601=seconds)"

notify_user() {
  local pid env line
  for pid in $(pgrep -u "$USER_NAME" -f .); do
    env="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null || true)"
    if printf '%s\n' "$env" | grep -q '^WAYLAND_DISPLAY='; then
      while IFS= read -r line; do
        case "$line" in
          WAYLAND_DISPLAY=*|DISPLAY=*|DBUS_SESSION_BUS_ADDRESS=*|XDG_RUNTIME_DIR=*) export "$line" ;;
        esac
      done <<<"$env"
      notify-send "cpolar tunnels" "$OUTPUT" && return 0
    fi
  done
  echo "no active graphical session for $USER_NAME, skip notify-send" >&2
  return 1
}
notify_user || true

ntfy publish \
  --title "${HOST_NAME} · cpolar tunnels" \
  --tags "satellite_antenna" \
  --priority "low" \
  --markdown \
  "$NTFY_TOPIC" "$MSG" || echo "ntfy publish failed" >&2
exit 0
