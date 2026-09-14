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
    ./apparmor-workaround.nix

    # ./vscode-remote-workaround.nix
  ];

  # WSL has no wireless hardware, disable wpa_supplicant
  networking.wireless.enable = lib.mkForce false;

  # Service accounts required by agenix secrets (cpolar.yml, alist-jwt)
  users.users.alist = {
    isSystemUser = true;
    group = "nogroup";
  };

  users.users.cpolar = {
    isSystemUser = true;
    group = "cpolar";
  };
  users.groups.cpolar = { };

  users.users.cliproxyapi = {
    isSystemUser = true;
    group = "cliproxyapi";
  };
  users.groups.cliproxyapi = { };

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
