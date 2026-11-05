# If a future package provides `acb`, rename this dispatcher to `acbctl`.
usage() {
  cat <<'EOF'
usage: acb <command> [args...]

commands:
  up      start acb-stack.target, or one component (bridge / drivers / dsh / opencode)
  down    stop acb-stack.target, or one component
  status  show dependency and unit readiness
  logs    follow ACB logs (dsh / bridge / drivers / opencode)
  stack   start acb-stack.target, wait for readiness, print summary
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
