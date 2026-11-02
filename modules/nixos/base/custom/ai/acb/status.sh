set -uo pipefail
for unit in dsh-acb acb-bridge acb-drivers acb-opencode-serve; do
  printf '%-22s %s\n' "$unit" "$(systemctl --user is-active "$unit.service" 2>/dev/null || true)"
done

echo "端口："
ss -tln 2>/dev/null | grep -E ":(("@DSH_PORT@")|("@ENDPOINT_PORT@")|("@CONSOLE_PORT@")|("@OPENCODE_PORT@")|("@RELAY_PORT@")|("@SNOWLUMA_PORT@")) " || echo "  （无）"
if ss -tln 2>/dev/null | grep -q ":@SNOWLUMA_PORT@ "; then
  echo "snowluma：在跑（@SNOWLUMA_PORT@）"
else
  echo "snowluma：没在监听 @SNOWLUMA_PORT@（先 podman compose up）"
fi

token_line=$(grep -o 'http://127\.0\.0\.1:@DSH_PORT@/?token=[A-Za-z0-9_-]*' "@LOG_DIR@/dsh.log" 2>/dev/null | tail -1)
[[ -n $token_line ]] && echo "dsh UI： $token_line"
echo "opencode：http://127.0.0.1:@OPENCODE_PORT@（用户 opencode，密码见 @DATA@/config/opencode.env）"

token=$(awk '
  /^\[console\]/ { f = 1; next }
  /^\[/          { f = 0 }
  f && /^token = / { gsub(/^token = "|"[[:space:]]*$/, ""); print; exit }
' "@CONFIG@" 2>/dev/null || true)
echo -n "桥自述： "
curl -s --max-time 3 -H "Authorization: Bearer ${token}" \
  http://127.0.0.1:@CONSOLE_PORT@/api/status || echo "（取不到）"
echo
echo "日志：@LOG_DIR@"
