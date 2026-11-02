#!/usr/bin/env bash
# pinentry-dispatch - draw the pinentry prompt where the caller can see it.
#
# Usage: pinentry <curses-pinentry> <qt-pinentry> [pinentry arguments...]
#
# gpg-agent starts this binary once per prompt, with the environment of the
# requesting client: it exports the client's terminal as GPG_TTY when there is
# one (the Assuan `OPTION ttyname` round trip) and leaves it unset for a client
# without a controlling terminal, which is exactly a browser's native-messaging
# host. The decision is therefore made on GPG_TTY and not on DISPLAY, because a
# desktop session sets DISPLAY/WAYLAND_DISPLAY for terminals too.
#
#   character-device GPG_TTY  -> draw in that terminal (the curses pinentry)
#   otherwise, a usable GUI   -> pop a window (the Qt pinentry)
#   neither (plain ssh, cron) -> curses, which reports a sane error
#
# "Usable" means drawable, not merely set. On WSL, DISPLAY survives after WSLg
# stops and older setups export one pointing at a Windows X server that is no
# longer installed; a Qt dialog that cannot connect times out and the prompt is
# lost, which is worse than the terminal prompt. So the display is probed:
#
#   WAYLAND_DISPLAY  -> $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY socket exists
#   DISPLAY=:N       -> /tmp/.X11-unix/XN socket exists
#   DISPLAY=host:N   -> TCP host:6000+N accepts a connection (1s timeout)
#
# Known edge: launching the browser from a terminal exports GPG_TTY into it, so
# the extension's prompts go to that terminal as well. Starting it from the
# desktop launcher - the normal case - leaves the variable unset.

set -o errexit -o nounset -o pipefail

curses="${1:?pinentry-dispatch: missing the path to the curses pinentry}"
qt="${2:?pinentry-dispatch: missing the path to the Qt pinentry}"
shift 2

display_ready() {
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    case "$WAYLAND_DISPLAY" in
      /*)
        if [ -S "$WAYLAND_DISPLAY" ]; then
          return 0
        fi
        ;;
      *)
        if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
          return 0
        fi
        ;;
    esac
  fi

  local display="${DISPLAY:-}"
  if [ -z "$display" ]; then
    return 1
  fi
  # drop the screen suffix: :0.0 -> :0, host:10.0 -> host:10
  display="${display%.[0-9]*}"

  case "$display" in
    unix:*)
      [ -S "/tmp/.X11-unix/X${display#unix:}" ]
      ;;
    :*)
      [ -S "/tmp/.X11-unix/X${display#:}" ]
      ;;
    *:*)
      local host="${display%:*}"
      local number="${display##*:}"
      if [ -z "$number" ]; then
        return 1
      fi
      if [ "$host" = localhost ]; then
        host=127.0.0.1
      fi
      timeout 1 bash -c "exec 3<>/dev/tcp/$host/$((6000 + number))" 2>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

if [ -n "${GPG_TTY:-}" ] && [ -c "$GPG_TTY" ]; then
  exec "$curses" "$@"
fi

if display_ready; then
  exec "$qt" "$@"
fi

exec "$curses" "$@"
