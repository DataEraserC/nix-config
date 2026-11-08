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

run systemctl --user start acb-bridge.service || {
  echo "acb-bridge 启动失败" >&2
  exit 1
}

wait_http "http://@DSH_HOST@:@DSH_PORT@/" "dsh" || {
  echo "dsh 未就绪；acb-bridge 已启动，继续汇总" >&2
}
wait_tcp "@ENDPOINT_PORT@" "桥" || {
  echo "桥未就绪；acb-bridge 已启动，继续汇总" >&2
}

echo "acb-bridge 已启动（dsh / drivers / opencode 由 acbl 组件管理）；\`acb down\` 会停止该单元"

if [[ $dry_run == yes ]]; then
  printf '[dry-run] %s --summary\n' "@STATUS@"
else
  "@STATUS@" --summary || true
fi
