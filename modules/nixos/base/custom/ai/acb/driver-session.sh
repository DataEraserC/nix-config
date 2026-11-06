token=$(session_token "@ID@")
if [[ -z $token ]]; then
  echo "config.toml 里没有会话 @ID@ 的 token，跳过" >&2
else
  env DSH_HOME="${DSH_HOME:-$HOME/.dsh}" \
    ACB_ENDPOINT="@ENDPOINT@" \
    ACB_TOKEN="$token" \
    ACB_HARNESS=dsh \
    ACB_PRESET="@PRESET@" \
    ACB_MCP_PORT="@PORT@" \
    DSH_BASE_URL="@DSH_URL@" \
    node "${DRIVER_SCRIPT:-@DRIVER@}" &
fi
