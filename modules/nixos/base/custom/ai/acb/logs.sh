set -uo pipefail
for name in dsh bridge drivers opencode; do
  echo "=== $name ==="
  tail -n "${LINES:-30}" "@LOG_DIR@/$name.log" 2>/dev/null || echo "（没有日志）"
done
