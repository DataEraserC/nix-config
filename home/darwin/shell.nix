_: {
  # Homebrew's default install location:
  #   /opt/homebrew for Apple Silicon
  #   /usr/local for macOS Intel
  # The prefix /opt/homebrew was chosen to allow installations
  # in /opt/homebrew for Apple Silicon and /usr/local for Rosetta 2 to coexist and use bottles.
  programs.bash.bashrcExtra = ''
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
  '';
  programs.zsh.envExtra = ''
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
  '';
}