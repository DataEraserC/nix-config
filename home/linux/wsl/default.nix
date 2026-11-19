{
  config,
  lib,
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

    # Input method for WSLg / waypipe GUI apps. WSLg's weston only exposes
    # text-input-v1 (no v3), so GTK/Qt must use the fcitx im-modules; see
    # https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland#Weston
    ../gui/base/fcitx5
    # flypy (小鹤音形) rime data, same as the desktop hosts.
    ../../base/gui/rime
  ];

  # Application launcher shared across all WSL hosts (usable via WSLg).
  home.packages = with pkgs; [
    anyrun
    python313
  ];

  # The shared fcitx5 module sets waylandFrontend = true, which makes Home
  # Manager leave GTK_IM_MODULE/QT_IM_MODULE unset in favour of
  # text-input-v3. WSLg's weston has no v3, so force the im-modules here.
  # XMODIFIERS/SDL_IM_MODULE/GLFW_IM_MODULE already come from the HM
  # fcitx5 module defaults.
  home.sessionVariables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
  };

  # WSLg's weston reserves zwp_input_method_v1 for its own RDP-side IME and
  # rejects other clients ("permission to bind input_method denied"), which
  # kills fcitx5 at startup when the waylandim addon loads. HM's
  # waylandFrontend only controls env vars, not the compiled-in addon, so
  # disable the addon at runtime instead. GTK/Qt/XIM talk to fcitx5 over
  # D-Bus/X11, which is all the im-module setup above needs.
  i18n.inputMethod.fcitx5.waylandFrontend = lib.mkForce false;

  # WSL has no login session and no graphical-session.target, so the HM
  # fcitx5-daemon unit (WantedBy = graphical-session.target) never starts.
  # Re-target it to default.target: lingering (modules/nixos/wsl/wsl_import.nix)
  # starts the user manager at boot, which then starts fcitx5.
  # DISPLAY/WAYLAND_DISPLAY point at WSLg's sockets; without them fcitx5
  # finds no display and exits immediately (status 0).
  systemd.user.services.fcitx5-daemon = {
    Unit = {
      PartOf = lib.mkForce [ ];
      After = lib.mkForce [ ];
    };
    Service = {
      Environment = [
        "DISPLAY=:0"
        "WAYLAND_DISPLAY=wayland-0"
      ];
      ExecStart = lib.mkForce "${config.i18n.inputMethod.package}/bin/fcitx5 --disable waylandim";
    };
    Install.WantedBy = lib.mkForce [ "default.target" ];
  };

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
