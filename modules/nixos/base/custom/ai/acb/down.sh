set -uo pipefail
if (( $# == 0 )); then
  targets=(all)
else
  targets=("$@")
fi
units=()
for target in "${targets[@]}"; do
  case "$target" in
    all) units+=(acb-stack.target) ;;
    bridge) units+=(acb-bridge.service) ;;
    drivers) units+=(acb-drivers.service) ;;
    opencode) units+=(acb-opencode-serve.service) ;;
    dsh) units+=(dsh-acb.service) ;;
    *) echo "不认识的组件：$target（可用：all / bridge / drivers / dsh / opencode）" >&2; exit 1 ;;
  esac
done

if (( ${#units[@]} > 0 )); then
  systemctl --user stop "${units[@]}"
fi
