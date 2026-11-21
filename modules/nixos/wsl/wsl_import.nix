{
  lib,
  myvars,
  ...
}:
{
  imports = [
    ../server/server.nix
    ../desktop/fonts.nix
    ../desktop/fhs.nix
    ../desktop/appcast.nix
    ../base/i18n.nix
    ../base/user-group.nix
    ../base/custom
    ./apparmor-workaround.nix
  ];

  # WSL has no wireless hardware, disable wpa_supplicant
  networking.wireless.enable = lib.mkForce false;

  # The WSL Home Manager profile imports gui/base/gtk.nix, whose activation
  # writes GTK settings through dconf. Without the system dconf D-Bus service
  # (normally pulled in by desktop modules WSL does not import), HM activation
  # fails at dconfSettings with "The name is not activatable".
  programs.dconf.enable = true;

  # Service accounts (cpolar, cliproxyapi, m365-copilot2api, opencode2api, ...)
  # are not declared here: every WSL host imports the shared pinned table
  # hosts/service-user-ids.nix, which declares them with fixed uid/gid.
  # The OpenSSH agent remembers private keys for you
  # so that you don’t have to type in passphrases every time you make an SSH connection.
  # Use `ssh-add` to add a key to the agent.
  programs.ssh.startAgent = true;

  # WSL launches the default shell directly without a PAM login, so systemd-logind
  # never registers a session for the default user and `user@.service` never starts
  # (`/run/user/$UID` missing => `systemctl --user` fails, ssh-agent won't run).
  # Enable lingering so the user manager starts at boot regardless of sessions.
  users.users.${myvars.username}.linger = true;
}
