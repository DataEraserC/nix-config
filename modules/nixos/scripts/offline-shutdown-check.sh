#!/usr/bin/env bash
# ===============================================================================
#
# offline-shutdown-check: power off when the machine stays offline for too long.
#
# Effective settings resolution (highest priority last):
#   1. nix-declared defaults, injected via systemd `environment`:
#        TARGETS            space separated list of hosts/IPs to ping
#        GRACE_SECONDS      offline duration(seconds) after which we power off
#   2. runtime override file(if present):
#        OFFLINE_SHUTDOWN_ENABLED           0 disables, 1 enables(default)
#        OFFLINE_SHUTDOWN_GRACE_SECONDS     overrides GRACE_SECONDS
#
# The override file lives under /run(tmpfs), so any runtime tweak made with the
# `offline-shutdown` command is temporary and reverts to the nix defaults after
# a reboot. It is re-read on every timer tick; no rebuild/service restart is
# needed to apply a change(it takes effect on the next tick at the latest).
#
# State: /run/offline-shutdown/offline-since (epoch seconds of the first failed
# probe). /run is wiped on reboot, so a reboot always restarts the grace period.
#
# Exit codes are intentionally 0 for every handled branch: a failed probe, a
# short offline window, or an override that disables the check is not a unit
# failure. Real failures surface as non-zero from the tools used here.
# ===============================================================================

set -euo pipefail

STATE_DIR=/run/offline-shutdown
STATE_FILE="$STATE_DIR/offline-since"
OVERRIDE_FILE="$STATE_DIR/override.env"

# --- defaults from nix ------------------------------------------------------
GRACE_SECONDS="${GRACE_SECONDS:-1800}"
ENABLED=1

# --- load runtime override (temporary, reboot-reset) ------------------------
if [ -r "$OVERRIDE_FILE" ]; then
  # shellcheck disable=SC1090
  while IFS='=' read -r _key _val; do
    case "$_key" in
      OFFLINE_SHUTDOWN_ENABLED) [ "$_val" = "1" ] && ENABLED=1 || ENABLED=0 ;;
      OFFLINE_SHUTDOWN_GRACE_SECONDS)
        if [ "$_val" -ge 0 ] 2>/dev/null; then
          GRACE_SECONDS="$_val"
        else
          echo "ignoring invalid OFFLINE_SHUTDOWN_GRACE_SECONDS=$_val in $OVERRIDE_FILE" >&2
        fi
        ;;
    esac
  done < "$OVERRIDE_FILE"
fi

# --- disabled via runtime override: disarm & do nothing ---------------------
if [ "$ENABLED" -ne 1 ]; then
  rm -f "$STATE_FILE"
  echo "offline-shutdown disabled by runtime override, skipping"
  exit 0
fi

# shellcheck disable=SC2310
is_online() {
  # no target configured -> treat as online, never power off
  if [ -z "${TARGETS:-}" ]; then
    return 0
  fi

  for target in $TARGETS; do
    if ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
      return 0
    fi
  done

  return 1
}

now() {
  date +%s
}

mkdir -p "$STATE_DIR"

if is_online; then
  # network is back (or nothing configured): cancel any pending poweroff
  rm -f "$STATE_FILE"
  exit 0
fi

# offline right now
if [ ! -f "$STATE_FILE" ]; then
  # start counting from now
  now >"$STATE_FILE"
  exit 0
fi

offline_since=$(cat "$STATE_FILE")
elapsed=$(( $(now) - offline_since ))

if [ "$elapsed" -ge "$GRACE_SECONDS" ]; then
  echo "offline for ${elapsed}s >= ${GRACE_SECONDS}s, powering off"
  systemctl poweroff
else
  echo "still offline for ${elapsed}s (power off after ${GRACE_SECONDS}s)"
fi
