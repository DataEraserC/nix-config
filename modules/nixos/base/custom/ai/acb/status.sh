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

# dsh: preferred when its HTTP endpoint answers, even if started outside systemd.
dsh_code=$(http_code "http://@DSH_HOST@:@DSH_PORT@/")
dsh_active=$(unit_active dsh-acb)
dsh_loaded=$(unit_loaded dsh-acb)
if [[ $dsh_code == 200 || $dsh_code == 401 ]]; then
  report dsh ok ready "http://@DSH_HOST@:@DSH_PORT@/ HTTP $dsh_code"
elif [[ $dsh_loaded == not-found ]]; then
  report dsh fail not_configured "dsh-acb unit not found; dsh is user-managed"
elif [[ $dsh_active != active ]]; then
  report dsh fail not_started "start acb-stack.target or use acb stack"
else
  report dsh fail unreachable "unit active but HTTP ${dsh_code:-000}; see @LOG_DIR@/dsh.log"
fi

# opencode: ACB-owned harness. Readiness = authenticated /api/info HTTP 200.
opencode_password_value=$(opencode_password)
opencode_code=$(http_basic_code "http://@OPENCODE_HOST@:@OPENCODE_PORT@/api/info" opencode "$opencode_password_value")
opencode_active=$(unit_active acb-opencode-serve)
opencode_loaded=$(unit_loaded acb-opencode-serve)
if [[ $opencode_code == 200 ]]; then
  report opencode ok ready "http://@OPENCODE_HOST@:@OPENCODE_PORT@/api/info HTTP 200"
elif [[ $opencode_loaded == not-found ]]; then
  report opencode fail not_configured "acb-opencode-serve unit not found"
elif [[ $opencode_active != active ]]; then
  report opencode fail not_started "start acb-stack.target or use acb stack"
elif [[ $opencode_code == 401 || $opencode_code == 403 ]]; then
  report opencode fail auth_fail "HTTP $opencode_code: ACB_OPENCODE_PASSWORD mismatch; see @LOG_DIR@/opencode.log"
else
  report opencode fail unreachable "unit active but /api/info HTTP ${opencode_code:-000}; see @LOG_DIR@/opencode.log"
fi

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
  report bridge fail not_started "start acb-stack.target or use acb stack"
fi

# drivers are ACB-owned; active state is enough for the local readiness view.
drivers_active=$(unit_active acb-drivers)
drivers_loaded=$(unit_loaded acb-drivers)
if [[ $drivers_active == active ]]; then
  report drivers ok ready "acb-drivers unit active"
elif [[ $drivers_loaded == not-found ]]; then
  report drivers fail not_configured "acb-drivers unit not found"
else
  report drivers fail not_started "start acb-stack.target or use acb stack"
fi

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
