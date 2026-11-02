# pinentry-dispatch - one `pinentry` binary that picks its flavour per caller.
#
# `programs.gnupg.agent.pinentryPackage` takes a single package and
# /etc/gnupg/gpg-agent.conf can name a single `pinentry-program`, so a machine
# that runs `pass` in a terminal *and* a browser pass extension has to pick a
# loser: curses-only breaks the browser (there is no terminal to draw in),
# Qt-only pops a window over the shell the user is already typing in.
#
# The decision needs the caller's environment, so it is made at runtime by
# ./pinentry-dispatch/pinentry.sh, which this overlay installs as `bin/pinentry`
# with the two flavours passed as arguments. That file documents the cases, and
# why the display is probed instead of trusted. The overlay sits in a directory
# rather than beside the script because `overlays/default.nix` imports every
# entry of `overlays/`, so a sibling `pinentry.sh` would be read as an overlay.
#
# The first pattern is mandatory: `overlays/default.nix` does
# `import <file> args`, so every overlay here is `args: final: prev:` - a plain
# `final: prev:` gets its `final` eaten by the import and nixpkgs then calls the
# resulting attrset as a function.
{ ... }:
_final: prev:
let
  inherit (prev)
    bash
    coreutils
    lib
    pinentry-curses
    pinentry-qt
    writeShellApplication
    ;
in
{
  pinentry-dispatch = writeShellApplication {
    # the name matters: it is the built binary's path (`bin/pinentry`), which is
    # what `lib.getExe` and therefore gpg-agent.conf point at
    name = "pinentry";
    runtimeInputs = [
      bash # the dispatcher's shebang, and its /dev/tcp probe
      coreutils # timeout, for that probe
    ];
    text = "exec ${./pinentry.sh} ${lib.getExe pinentry-curses} ${lib.getExe pinentry-qt} \"$@\"";
    meta = {
      description = "pinentry that prompts in the terminal for terminal callers and opens the Qt dialog for GUI callers";
      mainProgram = "pinentry";
    };
  };
}
