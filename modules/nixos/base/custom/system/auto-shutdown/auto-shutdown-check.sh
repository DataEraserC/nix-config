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
#        CONDITION_NAMES  space separated labels matching CONDITIONS(for logs)
#        MODE             how the conditions are combined: all|any
#        GRACE_SECONDS    duration(seconds) in the shutdown-worthy state
#                         after which we power off
#        VERBOSE          1 logs every condition result + verdict each tick
#   2. runtime override file(if present):
#        AUTO_SHUTDOWN_ENABLED           0 disables, 1 enables(default)
#        AUTO_SHUTDOWN_GRACE_SECONDS     overrides GRACE_SECONDS
#
# Logs go to the journal(`journalctl -u auto-shutdown`). State transitions and
# the final power-off are always logged; per-condition results only when
# VERBOSE=1.
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
VERBOSE="${VERBOSE:-0}"
ENABLED=1

# verbose-only logging helper(state transitions/poweroff use plain echo below)
log() {
  if [ "$VERBOSE" = "1" ]; then
    echo "auto-shutdown: $*"
  fi
}

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
    log "no conditions configured -> OK (never powers off)"
    return 0
  fi

  local mode="${MODE:-all}"
  local -a conds names
  read -r -a conds <<<"$CONDITIONS"
  read -r -a names <<<"${CONDITION_NAMES:-}"

  # run every condition so the log shows all results, not just until the first
  # short-circuit; the number of checks is small and runs at most once per tick.
  local total="${#conds[@]}"
  local passed=0 i cond name
  for i in "${!conds[@]}"; do
    cond="${conds[$i]}"
    name="${names[$i]:-$cond}"
    if "$cond" >/dev/null 2>&1; then
      passed=$((passed + 1))
      log "[ok]   $name"
    else
      log "[fail] $name"
    fi
  done

  if [ "$mode" = "any" ]; then
    if [ "$passed" -gt 0 ]; then
      log "verdict: OK (${passed}/${total} passed, mode=any)"
      return 0
    fi
    log "verdict: shutdown-worthy (${passed}/${total} passed, mode=any)"
    return 1
  fi

  if [ "$passed" -eq "$total" ]; then
    log "verdict: OK (${passed}/${total} passed, mode=all)"
    return 0
  fi
  log "verdict: shutdown-worthy (${passed}/${total} passed, mode=all)"
  return 1
}

now() {
  date +%s
}

mkdir -p "$STATE_DIR"

if is_ok; then
  # conditions OK again (or nothing configured): cancel any pending poweroff
  if [ -f "$STATE_FILE" ]; then
    echo "auto-shutdown: conditions OK again after $(( $(now) - $(cat "$STATE_FILE") ))s, cancelling countdown"
  fi
  rm -f "$STATE_FILE"
  exit 0
fi

# in a shutdown-worthy state right now
if [ ! -f "$STATE_FILE" ]; then
  # start counting from now
  now >"$STATE_FILE"
  echo "auto-shutdown: shutdown-worthy, starting ${GRACE_SECONDS}s countdown"
  exit 0
fi

failing_since=$(cat "$STATE_FILE")
elapsed=$(( $(now) - failing_since ))

if [ "$elapsed" -ge "$GRACE_SECONDS" ]; then
  echo "auto-shutdown: shutdown-worthy for ${elapsed}s >= ${GRACE_SECONDS}s, powering off"
  systemctl poweroff
else
  echo "auto-shutdown: still shutdown-worthy for ${elapsed}s (power off after ${GRACE_SECONDS}s)"
fi
