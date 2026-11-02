set -uo pipefail

config="@CONFIG@"
[[ -f $config ]] || { echo "没有 $config" >&2; exit 1; }

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
