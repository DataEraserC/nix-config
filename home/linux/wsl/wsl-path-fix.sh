wsl-path-fix() {
  local full _wsl_ver
  [ -r /proc/version ] || return 1
  IFS= read -r _wsl_ver < /proc/version
  case $_wsl_ver in
    *[Mm]icrosoft* | *WSL*) ;;
    *) return 1 ;;
  esac
  [ -x /mnt/c/Windows/System32/wsl.exe ] || return 1
  full="$(/mnt/c/Windows/System32/wsl.exe echo '$PATH')" || return 1
  [ -n "$full" ] || return 1
  export PATH="$full"
}
