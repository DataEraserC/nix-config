set -uo pipefail

summary=no
if [[ ${1:-} == --summary ]]; then
  summary=yes
fi

unit_active() { systemctl --user is-active "$1.service" 2>/dev/null || true; }
unit_loaded() { systemctl --user show "$1.service" -p LoadState --value 2>/dev/null || true; }
http_code() { curl -sS -o /dev/null --max-time 2 -w '%{http_code}' "$1" 2>/dev/null || true; }
http_code_auth() {
  curl -sS -o /dev/null --max-time 2 -H "Authorization: Bearer $2" -w '%{http_code}' "$1" 2>/dev/null || true
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
  report dsh fail not_started "start dsh-acb or use acb stack"
else
  report dsh fail unreachable "unit active but HTTP ${dsh_code:-000}; see @LOG_DIR@/dsh.log"
fi

# opencode: external component; same shape as dsh.
opencode_code=$(http_code "http://@OPENCODE_HOST@:@OPENCODE_PORT@/")
opencode_active=$(unit_active acb-opencode-serve)
opencode_loaded=$(unit_loaded acb-opencode-serve)
if [[ $opencode_code == 200 || $opencode_code == 401 ]]; then
  report opencode ok ready "http://@OPENCODE_HOST@:@OPENCODE_PORT@/ HTTP $opencode_code"
elif [[ $opencode_loaded == not-found ]]; then
  report opencode fail not_configured "acb-opencode-serve unit not found"
elif [[ $opencode_active != active ]]; then
  report opencode fail not_started "start acb-opencode-serve (external component)"
else
  report opencode fail unreachable "unit active but HTTP ${opencode_code:-000}; see @LOG_DIR@/opencode.log"
fi

# bridge: requires its console token; /api/status is the local self-report.
token=$(awk '
  /^\[console\]/ { f = 1; next }
  /^\[/          { f = 0 }
  f && /^token = / { gsub(/^token = "|"[[:space:]]*$/, "", $0); print; exit }
' "@CONFIG@" 2>/dev/null || true)
bridge_active=$(unit_active acb-bridge)
bridge_loaded=$(unit_loaded acb-bridge)
bridge_code=""
if [[ $bridge_active == active ]]; then
  if [[ -z $token ]]; then
    report bridge fail not_configured "console token missing in @CONFIG@"
  else
    bridge_code=$(http_code_auth "http://@CONSOLE_HOST@:@CONSOLE_PORT@/api/status" "$token")
    if [[ $bridge_code == 200 ]]; then
      report bridge ok ready "http://@CONSOLE_HOST@:@CONSOLE_PORT@/api/status HTTP $bridge_code"
    else
      report bridge fail unreachable "unit active but HTTP ${bridge_code:-000}; see @LOG_DIR@/bridge.log"
    fi
  fi
elif [[ $bridge_loaded == not-found ]]; then
  report bridge fail not_configured "acb-bridge unit not found"
else
  report bridge fail not_started "start acb-bridge (acb up)"
fi

# drivers are ACB-owned; active state is enough for the local readiness view.
drivers_active=$(unit_active acb-drivers)
drivers_loaded=$(unit_loaded acb-drivers)
if [[ $drivers_active == active ]]; then
  report drivers ok ready "acb-drivers unit active"
elif [[ $drivers_loaded == not-found ]]; then
  report drivers fail not_configured "acb-drivers unit not found"
else
  report drivers fail not_started "start acb-drivers (acb up drivers)"
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
