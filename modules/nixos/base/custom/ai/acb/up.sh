set -uo pipefail
if (( $# == 0 )); then
  targets=(all)
else
  targets=("$@")
fi
start_bridge=no
for target in "${targets[@]}"; do
  case "$target" in
    all | bridge) start_bridge=yes ;;
    drivers | dsh | opencode)
      echo "「$target」由 acbl 组件管理，不再由 systemd 启动；请用 acbctl component 等命令操作。" >&2
      exit 1
      ;;
    *) echo "不认识的组件：$target（可用：all / bridge）" >&2; exit 1 ;;
  esac
done

wait_tcp() {
  local port=$1 label=$2 deadline=$((SECONDS + 30))
  while (( SECONDS < deadline )); do
    ss -tln 2>/dev/null | grep -q ":$port " && { echo "    $label 已就绪（$port）"; return 0; }
    sleep 0.5
  done
  echo "    ⚠ $label 30 秒内没在 $port 上监听" >&2
  return 1
}

if [[ $start_bridge == yes ]]; then
  systemctl --user start acb-bridge.service || exit 1
  wait_tcp "@ENDPOINT_PORT@" "桥" || true
fi

"@STATUS@" --summary || true
