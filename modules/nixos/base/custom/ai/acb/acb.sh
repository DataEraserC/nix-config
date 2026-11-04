# If a future package provides `acb`, rename this dispatcher to `acbctl`.
usage() {
  cat <<'EOF'
usage: acb <command> [args...]

commands:
  up      start the ACB bridge (external components are user-managed)
  down    stop the ACB bridge and drivers
  status  show dependency and unit readiness
  logs    follow ACB logs
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
  "" | -h | --help)
    usage
    exit 1
    ;;
  *)
    usage
    exit 1
    ;;
esac
