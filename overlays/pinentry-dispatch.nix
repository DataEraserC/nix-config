# pinentry-dispatch - one `pinentry` binary that picks its flavour per caller.
#
# `programs.gnupg.agent.pinentryPackage` takes a single package and
# /etc/gnupg/gpg-agent.conf can name a single `pinentry-program`, so a machine
# that runs `pass` in a terminal *and* a browser pass extension has to pick a
# loser: curses-only breaks the browser (there is no terminal to draw in),
# Qt-only pops a window over the shell the user is already typing in.
#
# gpg-agent exports the requesting client's terminal as GPG_TTY right before it
# starts the pinentry (the Assuan `OPTION ttyname` round trip) and leaves it
# unset for a client without a controlling terminal, which is exactly the
# browser's native-messaging host. So the decision is made on GPG_TTY, not on
# DISPLAY: a desktop session sets DISPLAY/WAYLAND_DISPLAY for terminals too.
#
#   - character-device GPG_TTY  -> draw in that terminal (pinentry-curses)
#   - otherwise, a working GUI  -> pop a window (pinentry-qt)
#   - neither (plain ssh, cron) -> curses, which then reports a sane error
#
# The same binary is used on WSL, where either answer can be right depending on
# whether the session is a terminal one or a WSLg one, so it is a runtime
# decision there too: a WSLg session has WAYLAND_DISPLAY (:0 / wayland-0, with
# Qt's qtwayland plugin on QT_PLUGIN_PATH) and pinentry-qt renders natively,
# while a plain `wsl.exe` terminal has a GPG_TTY and no display at all.
#
# "A display" means one that can actually be drawn on, not just a set variable.
# WSL exports DISPLAY only while WSLg is running, and older setups export a
# stale one pointing at a Windows X server that is no longer installed; a Qt
# dialog that cannot connect is worse than the terminal prompt, so the local
# cases are probed:
#
#   WAYLAND_DISPLAY  -> $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY socket exists
#   DISPLAY=:N       -> /tmp/.X11-unix/XN socket exists
#   DISPLAY=host:N   -> TCP host:6000+N accepts a connection (1s timeout)
#
# Caveat: launching the browser from a terminal exports GPG_TTY into it, so the
# extension's prompts go to that terminal as well. Starting it from the desktop
# launcher - the normal case - leaves the variable unset.
# The first pattern is mandatory: `overlays/default.nix` does
# `import <file> args`, so every overlay here is `args: final: prev:` - a plain
# `final: prev:` gets its `final` eaten by the import and nixpkgs then calls the
# resulting attrset as a function.
{ ... }:
_final: prev:
let
  inherit (prev)
    lib
    pinentry-curses
    pinentry-qt
    writeShellApplication
    ;
  curses = lib.getExe pinentry-curses;
  qt = lib.getExe pinentry-qt;
in
{
  pinentry-dispatch = writeShellApplication {
    # the name matters: it is the built binary's path (`bin/pinentry`), which is
    # what `lib.getExe` and therefore gpg-agent.conf point at
    name = "pinentry";
    runtimeInputs = [ prev.coreutils ]; # timeout, for the TCP probe
    text = ''
      # Does a compositor or X server actually answer? Probing beats trusting
      # the variable: on WSL a stale DISPLAY otherwise turns every prompt into
      # a silent failure.
      display_ready() {
        if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
          case "$WAYLAND_DISPLAY" in
            /*) [ -S "$WAYLAND_DISPLAY" ] && return 0 ;;
            *)
              if [ -n "''${XDG_RUNTIME_DIR:-}" ] && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
                return 0
              fi
              ;;
          esac
        fi

        local display="''${DISPLAY:-}"
        [ -n "$display" ] || return 1
        # drop the screen suffix: :0.0 -> :0, host:10.0 -> host:10
        display="''${display%.[0-9]*}"

        case "$display" in
          unix:*)
            [ -S "/tmp/.X11-unix/X''${display#unix:}" ]
            ;;
          :*)
            [ -S "/tmp/.X11-unix/X''${display#:}" ]
            ;;
          *:*)
            local host="''${display%:*}"
            local number="''${display##*:}"
            [ -n "$number" ] || return 1
            [ "$host" = localhost ] && host=127.0.0.1
            timeout 1 bash -c "exec 3<>/dev/tcp/$host/$((6000 + number))" 2>/dev/null
            ;;
          *)
            return 1
            ;;
        esac
      }

      if [ -n "''${GPG_TTY:-}" ] && [ -c "$GPG_TTY" ]; then
        exec ${curses} "$@"
      fi

      if display_ready; then
        exec ${qt} "$@"
      fi

      exec ${curses} "$@"
    '';
    meta = {
      description = "pinentry that prompts in the terminal for terminal callers and opens the Qt dialog for GUI callers";
      mainProgram = "pinentry";
    };
  };
}
