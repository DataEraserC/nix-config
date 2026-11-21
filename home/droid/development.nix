{
  pkgs,
  ...
}:
let
in
{
  # Dev-only tools. Anything also shipped by ./system-tools.nix or the shared
  # home/base/tui/dev-tools.nix (direnv, editors, archive tools, gnupg, ...)
  # lives there, not here, so each package is declared exactly once.
  home.packages = with pkgs; [
    rsync # File Copy/Sync
    proxychains
    tmux # Background Shell process

    # User-facing stuff that you really really want to have
    vim # or some other editor, e.g. nano or neovim
    helix # An editor with lots of functions out of box
    git # Version Manager
    patch
    openssh
    curl
    gnumake
    just

    # Some common stuff that people expect to have
    fzf
    killall
    diffutils
    findutils
    util-linux
    tzdata
    hostname
    bzip2
    gzip
    ncurses # command clear
    htop
    netcat # nc
    procps # command ps/pgrep and ...
    time
  ];
  programs = {
    zsh = {
      enable = true;
    };
    nushell = {
      enable = true;
    };
    bash = {
      enable = true;
      enableCompletion = true;
    };
    fish = {
      enable = true;
    };
  };
}
