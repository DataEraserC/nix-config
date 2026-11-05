# If a future package provides `acb`, rename this dispatcher to `acbctl`.
usage() {
  cat <<'EOF'
usage: acb <command> [args...]

commands:
  up      start ACB units (bridge / drivers / opencode; dsh is user-managed)
  down    stop ACB units (bridge / drivers / opencode; dsh is user-managed)
  status  show dependency and unit readiness
  logs    follow ACB logs (dsh / bridge / drivers / opencode)
  stack   one-shot: dsh -> bridge -> opencode -> drivers (opencode failure degrades, no abort)
EOF
}

case "${1:-}" in
  up)
    shift
    exec "@UP@" "$@"
    ;;
  down)
    shift
    exec "@DOWN@" "$@"
    ;;
  status)
    shift
    exec "@STATUS@" "$@"
    ;;
  logs)
    shift
    exec "@LOGS@" "$@"
    ;;
  stack)
    shift
    exec "@STACK@" "$@"
    ;;
  "" | -h | --help)
    usage
    exit 1
    ;;
  *)
    usage
    exit 1
    ;;
esac
