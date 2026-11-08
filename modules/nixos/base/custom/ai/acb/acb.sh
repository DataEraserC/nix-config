# If a future package provides `acb`, rename this dispatcher to `acbctl`.
usage() {
  cat <<'EOF'
usage: acb <command> [args...]

commands:
  up      start acb-bridge (acbl 负责拉起受管组件)
  down    stop acb-bridge
  status  show dependency and unit readiness
  logs    follow ACB logs (dsh / bridge / drivers / opencode)
  stack   start acb-bridge, wait for readiness, print summary
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
