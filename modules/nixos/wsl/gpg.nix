{ lib, pkgs, ... }:
{
  # Curses only, on purpose: the callers here are terminal ones (pass, git
  # signing from the shell or from VS Code's integrated terminal), and the
  # desktop dispatcher (overlays/pinentry-dispatch.nix) would drag a Qt closure
  # into WSL for a dialog nothing on this host would ask for.
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
    enableSSHSupport = false;
    settings.default-cache-ttl = 4 * 60 * 60; # 4 hours
  };
}
