#!/usr/bin/env bash
# ===============================================================================
#
# auto-shutdown: temporarily tweak the auto-power-off behavior WITHOUT a nix
# rebuild. Writes /run/auto-shutdown/override.env, which the
# auto-shutdown.service re-reads on every tick. Because the file lives under
# /run(tmpfs), every change is reset to the nix-declared defaults on reboot.
#
# Usage:
#   auto-shutdown status                      show current override & state
#   auto-shutdown enable                      re-enable (undo a disable)
#   auto-shutdown disable                     disable until the next reboot
#   auto-shutdown grace <span>                e.g. 45min / 2h / 3600 (seconds)
#   auto-shutdown reset                       drop the override file entirely
#
# Examples:
#   sudo auto-shutdown disable                # tonight, don't auto power off
#   sudo auto-shutdown grace 1h               # power off only after 1h offline
# ===============================================================================

set -euo pipefail

STATE_DIR=/run/auto-shutdown
OVERRIDE_FILE="$STATE_DIR/override.env"
STATE_FILE="$STATE_DIR/failing-since"

span_to_seconds() {
  local span="$1"
  local num mul
  case "$span" in
    *min) num="${span%min}" mul=60 ;;
    *m) num="${span%m}" mul=60 ;;
    *h) num="${span%h}" mul=3600 ;;
    *d) num="${span%d}" mul=86400 ;;
    *s) num="${span%s}" mul=1 ;;
    *)
      if [[ "$span" =~ ^[0-9]+$ ]]; then
        echo "$span"
        return 0
      fi
      echo "invalid span: $span (expected e.g. 45min / 2h / 1d / 90s / 3600)" >&2
      return 1
      ;;
  esac
  echo "$((num * mul))"
}

read_override() {
  _enabled=1
  _grace=""
  if [ -f "$OVERRIDE_FILE" ]; then
    # shellcheck disable=SC1090
    while IFS='=' read -r _key _val; do
      case "$_key" in
        AUTO_SHUTDOWN_ENABLED) _enabled="$_val" ;;
        AUTO_SHUTDOWN_GRACE_SECONDS) _grace="$_val" ;;
      esac
    done < "$OVERRIDE_FILE"
  fi
}

write_override() {
  mkdir -p "$STATE_DIR"
  local out="$STATE_DIR/.override.env.tmp"
  : >"$out"
  if [ "$_enabled" = "0" ]; then
    printf 'AUTO_SHUTDOWN_ENABLED=%s\n' "$_enabled" >>"$out"
  fi
  if [ -n "$_grace" ]; then
    printf 'AUTO_SHUTDOWN_GRACE_SECONDS=%s\n' "$_grace" >>"$out"
  fi
  # nothing overridden -> drop the file so status reports "none"
  if [ ! -s "$out" ]; then
    rm -f "$out" "$OVERRIDE_FILE"
    return 0
  fi
  mv "$out" "$OVERRIDE_FILE"
}

cmd_status() {
  read_override
  echo "override file: ${OVERRIDE_FILE}"
  if [ ! -f "$OVERRIDE_FILE" ]; then
    echo "  (none - using nix-declared defaults; changes reset on reboot)"
    return 0
  fi
  echo "  enabled:  $([ "$_enabled" = 0 ] && echo 'no' || echo 'yes')"
  if [ -n "$_grace" ]; then
    echo "  grace:    ${_grace}s"
  fi
  if [ -f "$STATE_FILE" ]; then
    local since elapsed
    since=$(cat "$STATE_FILE")
    elapsed=$(( $(date +%s) - since ))
    echo "  failing:  ${elapsed}s (counting since boot/toggle)"
  else
    echo "  failing:  not counting (conditions OK or freshly booted)"
  fi
}

cmd_enable() {
  read_override
  _enabled=1
  write_override
  rm -f "$STATE_FILE"
  echo "auto-shutdown enabled (runtime override, until next reboot)"
}

cmd_disable() {
  read_override
  _enabled=0
  write_override
  rm -f "$STATE_FILE"
  echo "auto-shutdown disabled (runtime override, until next reboot)"
}

cmd_grace() {
  local seconds
  seconds=$(span_to_seconds "${1:?usage: auto-shutdown grace <span>}")
  read_override
  _grace="$seconds"
  write_override
  echo "auto-shutdown grace set to ${seconds}s (runtime override, until next reboot)"
}

cmd_reset() {
  rm -f "$OVERRIDE_FILE"
  echo "runtime override removed; nix-declared defaults restored (until reboot)"
}

if [ "$(id -u)" -ne 0 ]; then
  echo "auto-shutdown: needs root to write ${OVERRIDE_FILE}; re-run with sudo" >&2
  exit 1
fi

cmd="${1:-status}"
shift || true
case "$cmd" in
  status) cmd_status ;;
  enable) cmd_enable ;;
  disable) cmd_disable ;;
  grace) cmd_grace "${1:-}" ;;
  reset) cmd_reset ;;
  *)
    echo "usage: auto-shutdown {status|enable|disable|grace <span>|reset}" >&2
    exit 1
    ;;
esac
