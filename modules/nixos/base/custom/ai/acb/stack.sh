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

wait_opencode() {
  local url=$1 password=$2 code="" deadline=$((SECONDS + 30))
  if [[ $dry_run == yes ]]; then
    printf '[dry-run] wait for %s HTTP 200 (opencode basic auth)\n' "$url"
    return 0
  fi
  while (( SECONDS < deadline )); do
    code=$(http_basic_code "$url" opencode "$password")
    if [[ $code == 200 ]]; then
      echo "    opencode 已就绪（HTTP 200）"
      return 0
    fi
    sleep 0.5
  done
  echo "    opencode 30 秒内没有就绪：$url 最后 HTTP ${code:-无响应}" >&2
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

opencode_url="http://@OPENCODE_HOST@:@OPENCODE_PORT@/api/info"
opencode_password_value=$(opencode_password)
opencode_code=$(http_basic_code "$opencode_url" opencode "$opencode_password_value")
opencode_loaded=$(unit_loaded acb-opencode-serve)
opencode_degraded=no
if [[ $opencode_code == 200 ]]; then
  echo "opencode 已在运行（/api/info HTTP 200），跳过启动"
elif [[ $opencode_code == 401 || $opencode_code == 403 ]]; then
  opencode_degraded=yes
  echo "opencode /api/info HTTP $opencode_code（ACB_OPENCODE_PASSWORD 不匹配？）；继续启动 drivers" >&2
elif [[ $opencode_loaded == not-found ]]; then
  echo "acb-opencode-serve 未配置；跳过 opencode，继续启动 drivers" >&2
  opencode_degraded=yes
else
  run systemctl --user start acb-opencode-serve.service
  if ! wait_opencode "$opencode_url" "$opencode_password_value"; then
    opencode_degraded=yes
    echo "opencode 未就绪；继续启动 drivers（acb status 会显示失败）" >&2
  fi
fi

run systemctl --user start acb-drivers.service

if [[ $dsh_started == yes ]]; then
  echo "dsh 是本脚本启动的；\`acb down\` 不会停它，需要时手动 systemctl --user stop dsh-acb"
else
  echo "dsh 本来就在运行；\`acb down\` 不会停它"
fi

if [[ $opencode_degraded == yes ]]; then
  echo "opencode 未就绪；dsh/bridge/drivers 已继续启动，修复后用 acb status 复查" >&2
fi

if [[ $dry_run == yes ]]; then
  printf '[dry-run] %s --summary\n' "@STATUS@"
else
  "@STATUS@" --summary || true
fi
