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
    all) units+=(acb-bridge.service acb-drivers.service acb-opencode-serve.service) ;;
    bridge) units+=(acb-bridge.service) ;;
    drivers) units+=(acb-drivers.service) ;;
    opencode) units+=(acb-opencode-serve.service) ;;
    dsh) external+=("$target") ;;
    *) echo "不认识的组件：$target（可用：all / bridge / drivers / dsh / opencode）" >&2; exit 1 ;;
  esac
done

if (( ${#units[@]} > 0 )); then
  systemctl --user stop "${units[@]}"
fi

if (( ${#external[@]} > 0 )); then
  echo "外部组件（由用户停止）：${external[*]}" >&2
fi
