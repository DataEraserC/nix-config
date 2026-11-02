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
#   - otherwise, a display      -> pop a window (pinentry-qt)
#   - neither (plain ssh, cron) -> curses, which then reports a sane error
#
# Caveat: launching the browser from a terminal exports GPG_TTY into it, so the
# extension's prompts go to that terminal as well. Starting it from the desktop
# launcher - the normal case - leaves the variable unset.
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
    text = ''
      if [ -n "''${GPG_TTY:-}" ] && [ -c "$GPG_TTY" ]; then
        exec ${curses} "$@"
      fi

      if [ -n "''${WAYLAND_DISPLAY:-}" ] || [ -n "''${DISPLAY:-}" ]; then
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
