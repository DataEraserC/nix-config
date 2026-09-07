#!/usr/bin/env bash
# Notify on AC power loss/restore via ntfy(markdown).
#
# All inputs are injected by the systemd unit as environment variables, so this
# script stays free of any nix/config coupling:
#   HOST_NAME        target hostname, e.g. ai
#   NTFY_TOPIC_FILE  env-file providing $NTFY_TOPIC(required)
#   SEED_IF_EMPTY    "1" for timer mode(the first run is a boot baseline and must
#                    not notify), anything else for udev mode(where every run is
#                    a genuine power_supply change event).
#
# The current mains state is read from /sys/class/power_supply; the last
# notified state is kept under /run/power-event-notify/state(tmpfs), so:
#   - duplicate uevents for the same state are ignored,
#   - events that happen while suspended are delivered as change events on
#     resume and picked up here,
#   - the state resets on every boot(no stale notifications).
#
# Message spec(repo-wide): title "<host> · power lost|power restored",
# tags "warning"/"electric_plug", priority high/low, markdown body.
set -uo pipefail

# --------------------------------------------------------------------
# ntfy topic(sourced at runtime, never hardcoded)
# --------------------------------------------------------------------
topic_file="${NTFY_TOPIC_FILE:?NTFY_TOPIC_FILE must be set}"
if [ -f "$topic_file" ]; then
  . "$topic_file"
fi
if [ -z "${NTFY_TOPIC:-}" ]; then
  echo "ntfy topic unavailable($topic_file missing or NTFY_TOPIC empty), skip power notification" >&2
  exit 0
fi

# --------------------------------------------------------------------
# current mains state(no Mains device -> not a battery-powered laptop)
# --------------------------------------------------------------------
mains_dev=""
for dev in /sys/class/power_supply/*; do
  [ -d "$dev" ] || continue
  [ "$(cat "$dev/type" 2>/dev/null)" = "Mains" ] || continue
  mains_dev="$dev"
  break
done
if [ -z "$mains_dev" ]; then
  echo "no Mains power supply found, skip power notification" >&2
  exit 0
fi

ONLINE="$(cat "$mains_dev/online" 2>/dev/null)"
if [ "$ONLINE" = "1" ]; then
  CUR="on"
elif [ "$ONLINE" = "0" ]; then
  CUR="off"
else
  echo "cannot read Mains online state($mains_dev/online), skip power notification" >&2
  exit 0
fi

# battery capacity(optional, included in the message when available)
CAPACITY=""
for dev in /sys/class/power_supply/*; do
  [ -d "$dev" ] || continue
  [ "$(cat "$dev/type" 2>/dev/null)" = "Battery" ] || continue
  CAPACITY="$(cat "$dev/capacity" 2>/dev/null)"
  [ -n "$CAPACITY" ] && break
done

# --------------------------------------------------------------------
# edge detection vs. last notified state(/run, cleared on every boot)
# --------------------------------------------------------------------
STATE_DIR=/run/power-event-notify
STATE_FILE="$STATE_DIR/state"

PREV=""
[ -f "$STATE_FILE" ] && PREV="$(cat "$STATE_FILE" 2>/dev/null)"

if [ -z "$PREV" ]; then
  if [ "${SEED_IF_EMPTY:-0}" = "1" ]; then
    # timer mode: first run after boot establishes the baseline, no notify.
    install -d -m 0755 "$STATE_DIR"
    printf '%s\n' "$CUR" > "$STATE_FILE"
    echo "power-event-notify: baseline state $CUR(no notification on first run)" >&2
    exit 0
  fi
  # udev mode: every run is a real change event, so an empty state is a
  # genuine transition(after boot, no plug/unplug could have been missed).
  TRANSITIONED=1
elif [ "$PREV" != "$CUR" ]; then
  TRANSITIONED=1
else
  TRANSITIONED=0
fi

if [ "$TRANSITIONED" = "0" ]; then
  echo "power-event-notify: state unchanged($CUR), skip" >&2
  exit 0
fi

# --------------------------------------------------------------------
# state transition -> build & publish the message
# --------------------------------------------------------------------
if [ "$CUR" = "off" ]; then
  EVENT="power lost"
  TITLE="${HOST_NAME} · power lost"
  TAGS="warning"
  PRIO="high"
  SOURCE="battery"
else
  EVENT="power restored"
  TITLE="${HOST_NAME} · power restored"
  TAGS="electric_plug"
  PRIO="low"
  SOURCE="AC"
fi

POWER_LINE="**Power** ${SOURCE}"
if [ -n "$CAPACITY" ]; then
  POWER_LINE="$POWER_LINE (${CAPACITY}%)"
fi

MSG="**Host** ${HOST_NAME}
**Event** $EVENT
$POWER_LINE
**Time** $(date --iso-8601=seconds)"

ntfy publish \
  --title "$TITLE" \
  --tags "$TAGS" \
  --priority "$PRIO" \
  --markdown \
  "$NTFY_TOPIC" "$MSG" || echo "ntfy publish failed" >&2

# remember the state we just handled so duplicate uevents are ignored.
printf '%s\n' "$CUR" > "$STATE_FILE"
exit 0
