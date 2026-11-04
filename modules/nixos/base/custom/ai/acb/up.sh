set -uo pipefail
if (( $# == 0 )); then
  targets=(all)
else
  targets=("$@")
fi
units=()
external=()
for target in "${targets[@]}"; do
  case "$target" in
    all | bridge) units+=(acb-bridge.service) ;;
    drivers) units+=(acb-drivers.service) ;;
    dsh | opencode) external+=("$target") ;;
    *) echo "不认识的组件：$target（可用：all / bridge / drivers / dsh / opencode）" >&2; exit 1 ;;
  esac
done

mkdir -p "@DATA@" "@LOGS@"
ln -sfnT "@HARNESSES@" "@DATA@/harnesses"

ln -sfnT "@LUA@" "@DATA@/lua"

if (( ${#units[@]} > 0 )); then
  systemctl --user start "${units[@]}"
fi

wait_tcp() {
  local port=$1 label=$2 deadline=$((SECONDS + 30))
  while (( SECONDS < deadline )); do
    ss -tln 2>/dev/null | grep -q ":$port " && { echo "    $label 已就绪（$port）"; return 0; }
    sleep 0.5
  done
  echo "    ⚠ $label 30 秒内没在 $port 上监听" >&2
  return 1
}

if (( ${#units[@]} > 0 )); then
  wait_tcp "@ENDPOINT_PORT@" "桥" || true
fi

if (( ${#external[@]} > 0 )); then
  echo "外部组件（由用户启动，不在 acb up 管理范围内）：${external[*]}" >&2
fi

"@STATUS@" --summary || true
