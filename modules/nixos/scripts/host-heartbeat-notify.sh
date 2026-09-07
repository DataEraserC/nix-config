#!/usr/bin/env bash
# Periodically push a host liveness heartbeat via ntfy(markdown).
#
# All inputs are injected by the systemd unit as environment variables, so this
# script stays free of any nix/config coupling:
#   HOST_NAME                target hostname, e.g. ai
#   USER_NAME                primary username, e.g. nixos
#   NTFY_TOPIC_FILE          env-file providing $NTFY_TOPIC(required)
#   CPOLAR_CREDENTIALS_FILE  env-file providing CPOLAR_USERNAME/CPOLAR_PASSWORD
#   CPOLAR_STATUS_BIN        absolute path to the cpolar-status binary
# The cpolar section runs only when CPOLAR_STATUS_BIN is set; it is skipped
# gracefully when the credentials file is missing/unreadable.
#
# Message spec(repo-wide): title "<host> · heartbeat", tags "computer",
# priority "min", body rendered as markdown by the ntfy app.
set -uo pipefail

# --------------------------------------------------------------------
# ntfy topic(sourced at runtime, never hardcoded)
# --------------------------------------------------------------------
topic_file="${NTFY_TOPIC_FILE:?NTFY_TOPIC_FILE must be set}"
if [ -f "$topic_file" ]; then
  . "$topic_file"
fi
if [ -z "${NTFY_TOPIC:-}" ]; then
  echo "ntfy topic unavailable($topic_file missing or NTFY_TOPIC empty), skip heartbeat" >&2
  exit 0
fi

# --------------------------------------------------------------------
# host alive status(hostname / uptime / ISO8601 timestamp)
# --------------------------------------------------------------------
NOW="$(date --iso-8601=seconds)"
# prefer procps' pretty format, fall back to coreutils' plain output
UP="$(uptime -p 2>/dev/null)"
if [ -z "$UP" ]; then
  UP="$(uptime 2>/dev/null)"
fi

# power state(AC/battery + capacity), omitted when the host has no battery
POWER_LINE=""
mains_online=""
for dev in /sys/class/power_supply/*; do
  [ -d "$dev" ] || continue
  [ "$(cat "$dev/type" 2>/dev/null)" = "Mains" ] || continue
  mains_online="$(cat "$dev/online" 2>/dev/null)"
  break
done
capacity=""
for dev in /sys/class/power_supply/*; do
  [ -d "$dev" ] || continue
  [ "$(cat "$dev/type" 2>/dev/null)" = "Battery" ] || continue
  capacity="$(cat "$dev/capacity" 2>/dev/null)"
  [ -n "$capacity" ] && break
done
if [ -n "$mains_online" ] || [ -n "$capacity" ]; then
  if [ "$mains_online" = "1" ]; then
    POWER_LINE="**Power** AC"
  else
    POWER_LINE="**Power** battery"
  fi
  if [ -n "$capacity" ]; then
    POWER_LINE="$POWER_LINE (${capacity}%)"
  fi
fi
POWER_BLOCK=""
if [ -n "$POWER_LINE" ]; then
  POWER_BLOCK="
$POWER_LINE"
fi

MSG="**Host** ${HOST_NAME} (${USER_NAME})
**State** alive
**Uptime** ${UP:-unknown}
**Time** $NOW$POWER_BLOCK"

# --------------------------------------------------------------------
# network info(per-interface IPv4/IPv6 + public IP)
# --------------------------------------------------------------------
DEFAULT_IFACE="$(ip route show default 2>/dev/null | grep -oP 'dev \K\S+' | head -n1)"

# collect every interface(excluding loopback) with its IPs, one markdown list
# item each; the default outbound interface is annotated.
INTERFACES_INFO=""
for IFACE in $(ls /sys/class/net 2>/dev/null); do
  [ "$IFACE" = "lo" ] && continue

  IPV4_ADDR="$(ip -4 addr show dev "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)"
  IPV6_ADDR="$(ip -6 addr show dev "$IFACE" 2>/dev/null | grep -oP '(?<=inet6\s)[0-9a-f:]+' | grep -v '^fe80:' | head -n1)"

  PART=""
  [ -n "$IPV4_ADDR" ] && PART="IPv4 $IPV4_ADDR"
  if [ -n "$IPV6_ADDR" ]; then
    if [ -n "$PART" ]; then
      PART="$PART · IPv6 $IPV6_ADDR"
    else
      PART="IPv6 $IPV6_ADDR"
    fi
  fi

  MARK=""
  [ "$IFACE" = "$DEFAULT_IFACE" ] && MARK=" *(default)*"

  INTERFACES_INFO="$INTERFACES_INFO
- **$IFACE**$MARK ${PART:-no IP}"
done

PUBLIC_IP="$(curl -s -m 10 -4 ifconfig.co 2>/dev/null || curl -s -m 10 -6 ifconfig.co 2>/dev/null || true)"

MSG="$MSG

**Interfaces**${INTERFACES_INFO}"
if [ -n "$PUBLIC_IP" ]; then
  MSG="$MSG

**Public IP** $PUBLIC_IP"
fi

# --------------------------------------------------------------------
# cpolar tunnel status(skipped gracefully on any problem)
# --------------------------------------------------------------------
if [ -n "${CPOLAR_STATUS_BIN:-}" ]; then
  credentials_file="$CPOLAR_CREDENTIALS_FILE"
  if [ -f "$credentials_file" ]; then
    . "$credentials_file" 2>/dev/null
  fi
  if [ -z "${CPOLAR_USERNAME:-}" ] || [ -z "${CPOLAR_PASSWORD:-}" ]; then
    echo "cpolar credentials missing($credentials_file), skip cpolar status" >&2
  else
    OUTPUT="$("$CPOLAR_STATUS_BIN" --username "$CPOLAR_USERNAME" --password "$CPOLAR_PASSWORD")"
    if [ $? -eq 0 ]; then
      TUNNELS_MD="$(printf '%s\n' "$OUTPUT" | sed 's/^/- /')"
      MSG="$MSG

**Tunnels (cpolar)**
$TUNNELS_MD"
    else
      echo "cpolar-status failed, skip cpolar status" >&2
    fi
  fi
fi

# --------------------------------------------------------------------
# publish(markdown mode; failure is logged only, never fails the service)
# --------------------------------------------------------------------
ntfy publish \
  --title "${HOST_NAME} · heartbeat" \
  --tags "computer" \
  --priority "min" \
  --markdown \
  "$NTFY_TOPIC" "$MSG" || echo "ntfy publish failed" >&2
exit 0
