#!/usr/bin/env bash
# NetworkManager dispatcher hook: push a network event notification via ntfy
# and re-authenticate the tp_link router(anonymous host) on up/vpn-up events.
#
# NM contract: invoked as this-script <interface> <status>, with env vars like
# DEVICE_IFACE / CONNECTION_ID / CONNECTION_UUID provided by NetworkManager.
#
# All inputs are injected by the systemd unit(wrapper) as environment variables,
# so this script stays free of any nix/config coupling:
#   HOST_NAME        target hostname, e.g. ai
#   NTFY_TOPIC_FILE  env-file providing $NTFY_TOPIC(required)
#
# Message spec(repo-wide): title "<host> · network <status>",
# tags globe_with_meridians(up)/warning(down), priority default/high, markdown.
set -uo pipefail

INTERFACE=$1
STATUS=$2

notify_status(){
  if [ -f "$NTFY_TOPIC_FILE" ]; then
    . "$NTFY_TOPIC_FILE"
  else
    echo "No ntfy topic file found($NTFY_TOPIC_FILE)"
    return 1
  fi

  IPV4_ADDR=$(ip -4 addr show dev "$INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
  IPV6_ADDR=$(ip -6 addr show dev "$INTERFACE" 2>/dev/null | grep -oP '(?<=inet6\s)[0-9a-f:]+' | grep -v '^fe80:' | head -n1)
  get_public_ip() {
    local family endpoint response

    for family in -4 -6; do
      for endpoint in \
        "https://api64.ipify.org" \
        "https://ifconfig.co/ip" \
        "https://icanhazip.com"; do
        response="$(curl -fsS --max-time 5 "$family" "$endpoint" 2>/dev/null || true)"
        response="${response//$'\r'/}"
        response="${response//$'\n'/}"

        if [[ "$response" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] ||
           [[ "$response" =~ ^[0-9A-Fa-f:]+$ && "$response" == *:* ]]; then
          printf '%s\n' "$response"
          return 0
        fi
      done
    done

    return 1
  }

  PUBLIC_IP=$(get_public_ip || true)

  case "$STATUS" in
    down|vpn-down) TAGS="warning"; PRIO="high" ;;
    *)             TAGS="globe_with_meridians"; PRIO="default" ;;
  esac

  MSG="**Host** ${HOST_NAME}
**Iface** $DEVICE_IFACE
**Conn** $CONNECTION_ID ($CONNECTION_UUID)
**Event** $STATUS
**Time** $(date --iso-8601=seconds)

**Addresses**
- IPv4 ${IPV4_ADDR:-N/A}
- IPv6 ${IPV6_ADDR:-N/A}"
  if [ -n "$PUBLIC_IP" ]; then
    MSG="$MSG

**Public IP** $PUBLIC_IP"
  fi

  notify-send "Network $STATUS" "$DEVICE_IFACE: IPv4=${IPV4_ADDR:-N/A} Public=${PUBLIC_IP:-N/A}" || true
  ntfy publish \
    --title "${HOST_NAME} · network $STATUS" \
    --tags "$TAGS" \
    --priority "$PRIO" \
    --markdown \
    "$NTFY_TOPIC" "$MSG" || echo "ntfy publish failed" >&2
}

# 获取MAC地址函数
get_mac() {
    local interface="wlp0s20f3"
    local mac_file="/sys/class/net/$interface/address"

    if [[ -f "$mac_file" ]]; then
        cat "$mac_file"
        return 0
    else
        echo "Warning: Cannot get MAC address for network interface $interface" >&2
        echo "Warning: File $mac_file does not exist" >&2
        return 1
    fi
}
# 查找tp_link_script函数（严格版本）
find_tp_link_script() {
    local script_pattern="$HOME/.config/*/scripts/tp_link_script"
    local script_paths=($script_pattern)
    local script_path

    if [[ ${#script_paths[@]} -eq 0 ]]; then
        echo "Error: No tp_link_script found matching pattern: $script_pattern" >&2
        return 1
    elif [[ ${#script_paths[@]} -gt 1 ]]; then
        echo "Warning: Multiple tp_link_script files found, using the first one" >&2
        for path in "${script_paths[@]}"; do
            echo "  Found: $path" >&2
        done
    fi

    script_path="${script_paths[0]}"

    if [[ ! -f "$script_path" ]]; then
        echo "Error: tp_link_script not found: $script_path" >&2
        return 1
    fi

    if [[ ! -x "$script_path" ]]; then
        echo "Error: tp_link_script is not executable: $script_path" >&2
        return 1
    fi

    echo "$script_path"
    return 0
}

# 匿名函数
anonymous() {
    local mac_address
    local script_path

    # 获取MAC地址
    mac_address=$(get_mac)
    if [[ $? -ne 0 ]] || [[ -z "$mac_address" ]]; then
        echo "Error: Failed to get MAC address, aborting execution" >&2
        return 1
    fi

    # 查找tp_link_script
    script_path=$(find_tp_link_script)
    if [[ $? -ne 0 ]] || [[ -z "$script_path" ]]; then
        echo "Error: Cannot find tp_link_script, aborting execution" >&2
        return 1
    fi

    echo "Info: Using script: $script_path"
    echo "Info: MAC address: $mac_address"

    # 执行命令
    "$script_path" "http://192.168.0.1" "111111" "$mac_address" "Anonymous Host" "0"
}

case "$STATUS" in
  up)
    # 等待一下确保IP地址已经分配
    sleep 2
    notify_status
    anonymous
  ;;
  vpn-up)
    sleep 2
    notify_status
    anonymous
  ;;
  down)
    notify_status
  ;;
  vpn-down)
    notify_status
  ;;
esac

# NM ignores dispatcher exit codes, but keep this hook always-successful by
# contract: notification failures above are already logged only.
exit 0
