{
  lib,
  pkgs,
  ...
}:
{
  # Same dispatcher as the desktops (overlays/pinentry-dispatch.nix): a plain
  # `wsl.exe` terminal gets the curses prompt in that terminal, a WSLg session
  # gets the Qt dialog, and the choice is made per caller at runtime. WSL is
  # used both ways here, so pinning either flavour would be wrong half the time.
  # The cost is that pinentry-qt's Qt closure now sits in this host's runtime
  # closure whether or not WSLg is up; that is the price of the dynamic answer.
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-dispatch;
    enableSSHSupport = false;
    settings.default-cache-ttl = 4 * 60 * 60; # 4 hours
  };
}
