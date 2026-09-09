#!/usr/bin/env bash
# ===============================================================================
#
# auto-shutdown-check: power off when the machine stays in a shutdown-worthy
# state for too long.
#
# On every tick the *conditions* are run to decide whether to keep the machine
# on. Each condition is an executable path; exit 0 means "this check is OK":
#   MODE=all -> every condition must pass to keep the machine on
#   MODE=any -> at least one passing condition keeps it on
# Once the machine stays shutdown-worthy for GRACE_SECONDS, we power off.
#
# Effective settings resolution (highest priority last):
#   1. nix-declared defaults, injected via systemd `environment`:
#        CONDITIONS       space separated list of condition executables
#        MODE             how the conditions are combined: all|any
#        GRACE_SECONDS    duration(seconds) in the shutdown-worthy state
#                         after which we power off
#   2. runtime override file(if present):
#        AUTO_SHUTDOWN_ENABLED           0 disables, 1 enables(default)
#        AUTO_SHUTDOWN_GRACE_SECONDS     overrides GRACE_SECONDS
#
# The override file lives under /run(tmpfs), so any runtime tweak made with the
# `auto-shutdown` command is temporary and reverts to the nix defaults after a
# reboot. It is re-read on every timer tick; no rebuild/service restart is
# needed to apply a change(it takes effect on the next tick at the latest).
#
# State: /run/auto-shutdown/failing-since (epoch seconds of the first failed
# probe). /run is wiped on reboot, so a reboot always restarts the grace period.
#
# Exit codes are intentionally 0 for every handled branch: failing conditions,
# a short shutdown-worthy window, or an override that disables the check is not
# a unit failure. Real failures surface as non-zero from the tools used here.
# ===============================================================================

set -euo pipefail

STATE_DIR=/run/auto-shutdown
STATE_FILE="$STATE_DIR/failing-since"
OVERRIDE_FILE="$STATE_DIR/override.env"

# --- defaults from nix ------------------------------------------------------
GRACE_SECONDS="${GRACE_SECONDS:-1800}"
ENABLED=1

# --- load runtime override (temporary, reboot-reset) ------------------------
if [ -r "$OVERRIDE_FILE" ]; then
  # shellcheck disable=SC1090
  while IFS='=' read -r _key _val; do
    case "$_key" in
      AUTO_SHUTDOWN_ENABLED) [ "$_val" = "1" ] && ENABLED=1 || ENABLED=0 ;;
      AUTO_SHUTDOWN_GRACE_SECONDS)
        if [ "$_val" -ge 0 ] 2>/dev/null; then
          GRACE_SECONDS="$_val"
        else
          echo "ignoring invalid AUTO_SHUTDOWN_GRACE_SECONDS=$_val in $OVERRIDE_FILE" >&2
        fi
        ;;
    esac
  done < "$OVERRIDE_FILE"
fi

# --- disabled via runtime override: disarm & do nothing ---------------------
if [ "$ENABLED" -ne 1 ]; then
  rm -f "$STATE_FILE"
  echo "auto-shutdown disabled by runtime override, skipping"
  exit 0
fi

# shellcheck disable=SC2310
is_ok() {
  # no conditions configured -> always OK, never power off
  if [ -z "${CONDITIONS:-}" ]; then
    return 0
  fi

  local mode="${MODE:-all}"
  local cond
  if [ "$mode" = "any" ]; then
    # at least one passing condition keeps the machine on
    for cond in $CONDITIONS; do
      if "$cond" >/dev/null 2>&1; then
        return 0
      fi
    done
    echo "auto-shutdown: all conditions failing (mode=any)" >&2
    return 1
  fi
  # mode=all: every condition must pass
  for cond in $CONDITIONS; do
    if ! "$cond" >/dev/null 2>&1; then
      echo "auto-shutdown: condition '$cond' failing (mode=all)" >&2
      return 1
    fi
  done
  return 0
}

now() {
  date +%s
}

mkdir -p "$STATE_DIR"

if is_ok; then
  # conditions OK again (or nothing configured): cancel any pending poweroff
  rm -f "$STATE_FILE"
  exit 0
fi

# in a shutdown-worthy state right now
if [ ! -f "$STATE_FILE" ]; then
  # start counting from now
  now >"$STATE_FILE"
  exit 0
fi

failing_since=$(cat "$STATE_FILE")
elapsed=$(( $(now) - failing_since ))

if [ "$elapsed" -ge "$GRACE_SECONDS" ]; then
  echo "shutdown-worthy state for ${elapsed}s >= ${GRACE_SECONDS}s, powering off"
  systemctl poweroff
else
  echo "still in shutdown-worthy state for ${elapsed}s (power off after ${GRACE_SECONDS}s)"
fi
