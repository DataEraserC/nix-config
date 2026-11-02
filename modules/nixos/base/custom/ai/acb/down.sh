set -uo pipefail
if (( $# == 0 )); then
  targets=(all)
else
  targets=("$@")
fi
units=()
for target in "${targets[@]}"; do
  case "$target" in
    all) units+=(dsh-acb.service acb-bridge.service acb-drivers.service acb-opencode-serve.service) ;;
    bridge) units+=(acb-bridge.service) ;;
    drivers) units+=(acb-drivers.service) ;;
    dsh) units+=(dsh-acb.service) ;;
    opencode) units+=(acb-opencode-serve.service) ;;
    *) echo "不认识的组件：$target（可用：all / bridge / drivers / dsh / opencode）" >&2; exit 1 ;;
  esac
done
systemctl --user stop "${units[@]}"
