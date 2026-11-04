set -uo pipefail
if (( $# == 0 )); then
  targets=(all)
else
  targets=("$@")
fi
units=()
external=()
for target in "${targets[@]}"; do
  case "$target" in
    all) units+=(acb-bridge.service acb-drivers.service) ;;
    bridge) units+=(acb-bridge.service) ;;
    drivers) units+=(acb-drivers.service) ;;
    dsh | opencode) external+=("$target") ;;
    *) echo "不认识的组件：$target（可用：all / bridge / drivers / dsh / opencode）" >&2; exit 1 ;;
  esac
done

if (( ${#units[@]} > 0 )); then
  systemctl --user stop "${units[@]}"
fi

if (( ${#external[@]} > 0 )); then
  echo "外部组件（由用户停止，不在 acb down 管理范围内）：${external[*]}" >&2
fi
