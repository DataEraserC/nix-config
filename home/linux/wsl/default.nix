{
  pkgs,
  ...
}:
{
  imports = [
    # ../tui.nix
    ../../base/core
    ../../base/tui/wsl.nix
    ../../base/home.nix
    ../gui/base/gtk.nix

    ../base
    # ../gui/base/polkit-authentication-agent.nix
    # ../gui/base/fcitx5
  ];

  # Application launcher shared across all WSL hosts (usable via WSLg).
  home.packages = with pkgs; [
    anyrun
  ];

  # `wsl-path-fix`: restore a complete PATH when it has become incomplete, e.g.
  # after ssh-ing into a WSL host (sshd only passes a minimal PATH). It first
  # verifies that this really is a WSL kernel and that the Windows-side wsl.exe
  # is present, then rebuilds PATH from a fresh WSL shell:
  #
  #   export PATH=$(/mnt/c/Windows/System32/wsl.exe echo '$PATH')
  #
  # A child process cannot mutate its parent's PATH, so this is exposed as a
  # command in each configured shell instead of a plain executable.
  # The snippets live in standalone files (kept out of Nix strings so editors
  # can still syntax-highlight/lint them in their native language).
  programs.bash.bashrcExtra = builtins.readFile ./wsl-path-fix.sh;
  programs.fish.functions."wsl-path-fix".body = builtins.readFile ./wsl-path-fix.fish;
  programs.nushell.extraConfig = builtins.readFile ./wsl-path-fix.nu;
}
