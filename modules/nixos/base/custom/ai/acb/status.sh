set -uo pipefail

summary=no
if [[ ${1:-} == --summary ]]; then
  summary=yes
fi

unit_active() { systemctl --user is-active "$1.service" 2>/dev/null || true; }
unit_loaded() { systemctl --user show "$1.service" -p LoadState --value 2>/dev/null || true; }
http_code() { curl -sS -o /dev/null --max-time 2 -w '%{http_code}' "$1" 2>/dev/null || true; }
http_probe_auth() {
  local url=$1 token=$2 body
  body=$(curl -sS -o /dev/null --max-time 2 -H "Authorization: Bearer $token" -w '%{http_code}' "$url" 2>/dev/null)
  probe_rc=$?
  probe_code=${body:-000}
}
tcp_open() { ss -tln 2>/dev/null | grep -q ":$1 "; }

statuses=()
report() {
  local name=$1 result=$2 state=$3 hint=$4
  statuses+=("$name=$result")
  if [[ $summary == no ]]; then
    printf '%-10s %-5s %-14s %s\n' "$name" "$result" "$state" "$hint"
  fi
}

if [[ $summary == no ]]; then
  printf '%-10s %-5s %-14s %s\n' "依赖" "结果" "状态" "提示"
fi

# dsh: 由 acbl 组件管理，这里只按 HTTP 端口判断可达性。
dsh_code=$(http_code "http://@DSH_HOST@:@DSH_PORT@/")
if [[ $dsh_code == 200 || $dsh_code == 401 ]]; then
  report dsh ok ready "http://@DSH_HOST@:@DSH_PORT@/ HTTP $dsh_code"
else
  report dsh fail unreachable "dsh 由 acbl 管理；见 acbctl component status / @LOG_DIR@/dsh.log"
fi

# opencode 已由 acbl 组件管理，状态见 `acbctl component status`。

# bridge: requires its console token; /api/status is the local self-report.
config_token=$(awk '
  /^\[console\]/ { f = 1; next }
  /^\[/          { f = 0 }
  f && /^token = / { gsub(/^token = "|"[[:space:]]*$/, "", $0); print; exit }
' "@CONFIG@" 2>/dev/null || true)

token=""
# The `${` branch matches a literal placeholder; expanding it would break the check.
# shellcheck disable=SC2016
case "$config_token" in
  '${'*'}')
    inner=${config_token#\$\{}
    inner=${inner%\}}
    name=${inner%%:-*}
    fallback=""
    if [[ $inner == *:-* ]]; then
      fallback=${inner#*:-}
    fi
    if [[ $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      token=${!name:-$fallback}
    fi
    ;;
  *)
    token=$config_token
    ;;
esac

if [[ -z $token ]]; then
  env_files=$(systemctl --user show acb-bridge -p EnvironmentFiles --value 2>/dev/null | grep -o '/run/agenix/[^ ]*' || true)
  case " $env_files " in
    *" /run/agenix/acb.env "*) ;;
    *) env_files="$env_files /run/agenix/acb.env" ;;
  esac
  read -r -a env_files_arr <<< "$env_files"
  for env_file in "${env_files_arr[@]}"; do
    [[ -r $env_file ]] || continue
    token=$(awk -F= '$1=="ACB_CONSOLE_TOKEN"{sub(/^[^=]*=/,""); print; exit}' "$env_file" 2>/dev/null || true)
    token=${token%$'\r'}
    token=${token#\"}
    token=${token%\"}
    token=${token#\'}
    token=${token%\'}
    [[ -n $token ]] && break
  done
fi

version_mismatch=no
last_start=$(grep -n 'bridge running; press Ctrl-C to stop' "@LOG_DIR@/bridge.log" 2>/dev/null | tail -n 1 | cut -d: -f1)
if [[ -n $last_start ]]; then
  if tail -n +$((last_start + 1)) "@LOG_DIR@/bridge.log" 2>/dev/null | grep -q '协议版本不兼容\|protocol version.*mismatch'; then
    version_mismatch=yes
  fi
elif tail -n 30 "@LOG_DIR@/bridge.log" 2>/dev/null | grep -q '协议版本不兼容\|protocol version.*mismatch'; then
  version_mismatch=yes
fi

bridge_active=$(unit_active acb-bridge)
bridge_loaded=$(unit_loaded acb-bridge)
bridge_code=""
bridge_rc=0
if [[ $bridge_active == active ]]; then
  if [[ -z $token ]]; then
    report bridge fail not_configured "console token missing in @CONFIG@ and /run/agenix/acb.env"
  else
    http_probe_auth "http://@CONSOLE_HOST@:@CONSOLE_PORT@/api/status" "$token"
    bridge_code=$probe_code
    bridge_rc=$probe_rc
    if [[ $bridge_rc -ne 0 || $bridge_code == 000 ]]; then
      report bridge fail unreachable "unit active but no HTTP response (curl rc=$bridge_rc); see @LOG_DIR@/bridge.log"
    elif [[ $bridge_code == 401 || $bridge_code == 403 ]]; then
      report bridge fail auth_fail "HTTP $bridge_code: console token rejected; see @LOG_DIR@/bridge.log"
    elif [[ $bridge_code == 200 && $version_mismatch == no ]]; then
      report bridge ok ready "http://@CONSOLE_HOST@:@CONSOLE_PORT@/api/status HTTP $bridge_code"
    elif [[ $version_mismatch == yes ]]; then
      report bridge fail version_mismatch "HTTP $bridge_code but @LOG_DIR@/bridge.log reports protocol-version mismatch"
    else
      report bridge fail fail "unit active but HTTP $bridge_code; see @LOG_DIR@/bridge.log"
    fi
  fi
elif [[ $bridge_loaded == not-found ]]; then
  report bridge fail not_configured "acb-bridge unit not found"
else
  report bridge fail not_started "start acb-bridge (systemctl --user start acb-bridge.service or acb stack)"
fi

# drivers / dsh-presets 已由 acbl 组件管理，状态见 `acbctl component status`。

# snowluma is platform-side and has no ACB unit; only TCP visibility is possible here.
snowluma_port="@SNOWLUMA_PORT@"
if [[ -z $snowluma_port || $snowluma_port == 0 ]]; then
  report snowluma fail not_configured "snowluma port is not configured"
elif tcp_open "$snowluma_port"; then
  report snowluma ok ready "platform-side listener on $snowluma_port"
else
  report snowluma fail not_started "start platform-side snowluma (podman compose up)"
fi

if [[ $summary == yes ]]; then
  printf '依赖：%s\n' "${statuses[*]}"
  exit 0
fi

echo
echo "日志：@LOG_DIR@"
echo "dsh UI：http://@DSH_HOST@:@DSH_PORT@/"
echo "opencode：http://@OPENCODE_HOST@:@OPENCODE_PORT@/"
if [[ $bridge_code == 200 && -n $token ]]; then
  echo -n "桥自述： "
  curl -s --max-time 3 -H "Authorization: Bearer $token" \
    "http://@CONSOLE_HOST@:@CONSOLE_PORT@/api/status"
  echo
fi
