set -uo pipefail

config="@CONFIG@"
[[ -f $config ]] || { echo "没有 $config" >&2; exit 1; }

# driver.mjs 用 argv[1] 与 import.meta.url 比较来判定是否主模块，软链路径会导致
# 判断失败并静默退出，所以先把入口解析成真实 store 路径再交给 node。
driver_script=$(readlink -f -- "@DRIVER@") || {
  echo "无法解析 DSH 驱动脚本路径: @DRIVER@" >&2
  exit 1
}
if [[ ! -f $driver_script ]]; then
  echo "DSH 驱动脚本不存在: @DRIVER@（readlink -f 结果: ${driver_script:-空}）" >&2
  exit 1
fi
export DRIVER_SCRIPT="$driver_script"

session_token() {
  awk -v want="\"$1\"" '
    /^\[\[sessions\]\]$/ { ins=1; hit=0; next }
    /^\[\[/              { ins=0; next }
    ins && /^id = /      { hit = (index($0, want) > 0); next }
    ins && hit && /^token = / { gsub(/^token = "|"[[:space:]]*$/, ""); print; exit }
  ' "$config"
}

export ACB_CWD="@WORKSPACE@"
export ACB_WORKSPACE_TITLE="@TITLE@"
mkdir -p "$ACB_CWD"

@SESSIONS@

wait
