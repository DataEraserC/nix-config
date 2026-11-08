set -uo pipefail
if (( $# == 0 )); then
  targets=(all)
else
  targets=("$@")
fi
units=()
for target in "${targets[@]}"; do
  case "$target" in
    all | bridge) units+=(acb-bridge.service) ;;
    drivers | dsh | opencode)
      echo "「$target」由 acbl 组件管理，不再由 systemd 停止；请用 acbctl component 等命令操作。" >&2
      exit 1
      ;;
    *) echo "不认识的组件：$target（可用：all / bridge）" >&2; exit 1 ;;
  esac
done

if (( ${#units[@]} > 0 )); then
  systemctl --user stop "${units[@]}"
fi
