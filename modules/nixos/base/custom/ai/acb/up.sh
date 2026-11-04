set -uo pipefail
if (( $# == 0 )); then
  targets=(all)
else
  targets=("$@")
fi
units=()
for target in "${targets[@]}"; do
  case "$target" in
    all) units+=(dsh-acb.service acb-bridge.service acb-drivers.service acb-opencode-serve.service) ;;
    bridge) units+=(acb-bridge.service) ;;
    drivers) units+=(acb-drivers.service) ;;
    dsh) units+=(dsh-acb.service) ;;
    opencode) units+=(acb-opencode-serve.service) ;;
    *) echo "不认识的组件：$target（可用：all / bridge / drivers / dsh / opencode）" >&2; exit 1 ;;
  esac
done

mkdir -p "@DATA@" "@LOGS@"
ln -sfnT "@HARNESSES@" "@DATA@/harnesses"

ln -sfnT "@LUA@" "@DATA@/lua"

systemctl --user start "${units[@]}"

wait_dsh=no
wait_bridge=no
wait_opencode=no
for target in "${targets[@]}"; do
  case "$target" in
    all) wait_dsh=yes; wait_bridge=yes; wait_opencode=yes ;;
    dsh) wait_dsh=yes ;;
    bridge) wait_bridge=yes ;;
    opencode) wait_opencode=yes ;;
  esac
done

wait_http() {
  local url=$1 label=$2 code="" deadline=$((SECONDS + 30))
  while (( SECONDS < deadline )); do
    code=$(curl -sS -o /dev/null --max-time 2 -w '%{http_code}' "$url" 2>/dev/null || true)
    case "$code" in
      200|401) echo "    $label 已就绪（$url HTTP $code）"; return 0 ;;
    esac
    sleep 0.5
  done
  echo "    ⚠ $label 30 秒内没有就绪：$url 最后 HTTP ${code:-无响应}" >&2
  return 1
}

wait_tcp() {
  local port=$1 label=$2 deadline=$((SECONDS + 30))
  while (( SECONDS < deadline )); do
    ss -tln 2>/dev/null | grep -q ":$port " && { echo "    $label 已就绪（$port）"; return 0; }
    sleep 0.5
  done
  echo "    ⚠ $label 30 秒内没在 $port 上监听" >&2
  return 1
}

if [[ $wait_dsh == yes ]]; then wait_http "http://@DSH_HOST@:@DSH_PORT@/" "dsh" || true; fi
if [[ $wait_bridge == yes ]]; then wait_tcp "@ENDPOINT_PORT@" "桥" || true; fi
if [[ $wait_opencode == yes ]]; then wait_tcp "@OPENCODE_PORT@" "opencode" || true; fi

acb-status --summary || true
echo
exec acb-status
