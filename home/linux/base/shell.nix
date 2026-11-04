{
  config,
  myvars,
  ...
}:
let
  d = config.xdg.dataHome;
  c = config.xdg.configHome;
  cache = config.xdg.cacheHome;
in
rec {
  home.homeDirectory = "/home/${myvars.username}";

  # environment variables that always set at login
  home.sessionVariables = {
    # clean up ~
    LESSHISTFILE = cache + "/less/history";
    LESSKEY = c + "/less/lesskey";
    WINEPREFIX = d + "/wine";

    # set this variable make i3 failed to start
    # related issue:
    #   https://github.com/sddm/sddm/issues/871
    # XAUTHORITY = "$XDG_RUNTIME_DIR/Xauthority";

    # set default applications
    BROWSER = "firefox";

    # enable scrolling in git diff
    DELTA_PAGER = "less -R";
  };

  # gpg-agent can only learn a caller's terminal through GPG_TTY. SSH login
  # shells source this file via the generated ~/.profile; local GUI callers
  # keep the default Qt pinentry.
  home.sessionVariablesExtra = ''
    if [ -n "''${SSH_TTY:-}" ] || [ -n "''${SSH_CONNECTION:-}" ]; then
      if [ -t 0 ] || [ -t 1 ]; then
        _gpg_tty=$(tty 2>/dev/null) || _gpg_tty=
        if [ -c "''${_gpg_tty:-}" ]; then
          export GPG_TTY="$_gpg_tty"
        else
          unset GPG_TTY
        fi
        unset _gpg_tty
      fi
    fi
  '';
}
