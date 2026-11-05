set -uo pipefail
if (( $# == 0 )); then
  targets=(all)
else
  targets=("$@")
fi
start_bridge=no
start_drivers=no
start_opencode=no
opencode_required=no
external=()
for target in "${targets[@]}"; do
  case "$target" in
    all)
      start_bridge=yes
      start_drivers=yes
      start_opencode=yes
      ;;
    bridge) start_bridge=yes ;;
    drivers) start_drivers=yes ;;
    opencode)
      start_opencode=yes
      opencode_required=yes
      ;;
    dsh) external+=("$target") ;;
    *) echo "不认识的组件：$target（可用：all / bridge / drivers / dsh / opencode）" >&2; exit 1 ;;
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

http_basic_code() {
  local url=$1 user=$2 password=$3
  curl -sS -o /dev/null --max-time 2 -u "$user:$password" -w '%{http_code}' "$url" 2>/dev/null || true
}

read_env_value() {
  local file=$1 key=$2 value=""
  [[ -r $file ]] || return 0
  value=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1 | cut -d= -f2-)
  value=${value%$'\r'}
  value=${value#\"}
  value=${value%\"}
  value=${value#\'}
  value=${value%\'}
  printf '%s' "$value"
}

opencode_password() {
  local password files file
  password=$(read_env_value /run/agenix/acb.env ACB_OPENCODE_PASSWORD)
  if [[ -z $password ]]; then
    files=$(systemctl --user show acb-opencode-serve -p EnvironmentFiles --value 2>/dev/null | grep -o '/run/agenix/[^ ]*' || true)
    for file in $files; do
      password=$(read_env_value "$file" ACB_OPENCODE_PASSWORD)
      [[ -n $password ]] && break
    done
  fi
  printf '%s' "${password:-acb-opencode-local}"
}

wait_opencode() {
  local url=$1 password=$2 code="" deadline=$((SECONDS + 30))
  while (( SECONDS < deadline )); do
    code=$(http_basic_code "$url" opencode "$password")
    if [[ $code == 200 ]]; then
      echo "    opencode 已就绪（HTTP 200）"
      return 0
    fi
    sleep 0.5
  done
  echo "    ⚠ opencode 30 秒内没有就绪：$url 最后 HTTP ${code:-无响应}" >&2
  return 1
}

if [[ $start_bridge == yes ]]; then
  systemctl --user start acb-bridge.service
  wait_tcp "@ENDPOINT_PORT@" "桥" || true
fi

if [[ $start_opencode == yes ]]; then
  opencode_url="http://@OPENCODE_HOST@:@OPENCODE_PORT@/api/info"
  opencode_password_value=$(opencode_password)
  opencode_code=$(http_basic_code "$opencode_url" opencode "$opencode_password_value")
  if [[ $opencode_code == 200 ]]; then
    echo "opencode 已在运行（/api/info HTTP 200），跳过启动"
  elif [[ $opencode_code == 401 || $opencode_code == 403 ]]; then
    echo "opencode /api/info HTTP $opencode_code（ACB_OPENCODE_PASSWORD 不匹配？）" >&2
    [[ $opencode_required == yes ]] && exit 1
    echo "opencode 未就绪；继续（acb status 会显示失败）" >&2
  else
    opencode_loaded=$(systemctl --user show acb-opencode-serve.service -p LoadState --value 2>/dev/null || true)
    if [[ $opencode_loaded == not-found ]]; then
      echo "acb-opencode-serve 未配置；跳过 opencode" >&2
      [[ $opencode_required == yes ]] && exit 1
    else
      systemctl --user start acb-opencode-serve.service
      if ! wait_opencode "$opencode_url" "$opencode_password_value"; then
        [[ $opencode_required == yes ]] && exit 1
        echo "opencode 未就绪；继续（acb status 会显示失败）" >&2
      fi
    fi
  fi
fi

if [[ $start_drivers == yes ]]; then
  systemctl --user start acb-drivers.service
fi

if (( ${#external[@]} > 0 )); then
  echo "外部组件（由用户启动）：${external[*]}" >&2
fi

"@STATUS@" --summary || true
