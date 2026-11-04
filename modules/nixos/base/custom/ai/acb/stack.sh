set -uo pipefail

dry_run=no
if [[ ${1:-} == --dry-run ]]; then
  dry_run=yes
  shift
fi

run() {
  if [[ $dry_run == yes ]]; then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

unit_loaded() { systemctl --user show "$1.service" -p LoadState --value 2>/dev/null || true; }
http_code() {
  curl -sS -o /dev/null --max-time 2 -w '%{http_code}' "$1" 2>/dev/null || true
}

wait_http() {
  local url=$1 label=$2 code="" deadline=$((SECONDS + 30))
  if [[ $dry_run == yes ]]; then
    printf '[dry-run] wait for %s HTTP 200/401\n' "$url"
    return 0
  fi
  while (( SECONDS < deadline )); do
    code=$(http_code "$url")
    case "$code" in
      200 | 401) echo "    $label 已就绪（HTTP $code）"; return 0 ;;
    esac
    sleep 0.5
  done
  echo "    $label 30 秒内没有就绪：$url 最后 HTTP ${code:-无响应}" >&2
  return 1
}

wait_tcp() {
  local port=$1 label=$2 deadline=$((SECONDS + 30))
  if [[ $dry_run == yes ]]; then
    printf '[dry-run] wait for %s TCP %s\n' "$label" "$port"
    return 0
  fi
  while (( SECONDS < deadline )); do
    ss -tln 2>/dev/null | grep -q ":$port " && { echo "    $label 已就绪（$port）"; return 0; }
    sleep 0.5
  done
  echo "    $label 30 秒内没在 $port 上监听" >&2
  return 1
}

dsh_loaded=$(unit_loaded dsh-acb)
dsh_started=no
dsh_code=$(http_code "http://@DSH_HOST@:@DSH_PORT@/")
if [[ $dsh_code == 200 || $dsh_code == 401 ]]; then
  echo "dsh 已在运行（HTTP $dsh_code），跳过启动"
else
  if [[ $dsh_loaded == not-found ]]; then
    echo "dsh-acb 未配置；无法启动 dsh（dsh 是外部组件）" >&2
    exit 1
  fi
  run systemctl --user start dsh-acb.service
  dsh_started=yes
  wait_http "http://@DSH_HOST@:@DSH_PORT@/" "dsh" || {
    echo "dsh 未就绪，未启动桥与 drivers" >&2
    exit 1
  }
fi

run systemctl --user start acb-bridge.service
wait_tcp "@ENDPOINT_PORT@" "桥" || {
  echo "桥未就绪，未启动 drivers" >&2
  exit 1
}

run systemctl --user start acb-drivers.service

if [[ $dsh_started == yes ]]; then
  echo "dsh 是本脚本启动的；\`acb down\` 不会停它，需要时手动 systemctl --user stop dsh-acb"
else
  echo "dsh 本来就在运行；\`acb down\` 不会停它"
fi

if [[ $dry_run == yes ]]; then
  printf '[dry-run] %s --summary\n' "@STATUS@"
else
  "@STATUS@" --summary || true
fi
