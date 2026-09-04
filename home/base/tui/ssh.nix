{
  config,
  mysecrets,
  lib,
  ...
}:
{
  home.file.".ssh/romantic.pub".source = "${mysecrets}/public/romantic.pub";
  home.file.".ssh/gluttony.pub".source = "${mysecrets}/public/gluttony.pub";
  home.file.".ssh/juliet-age.pub".source = "${mysecrets}/public/juliet-age.pub";
  home.file.".ssh/idols-ai_id_rsa.pub".source = "${mysecrets}/public/idols-ai_id_rsa.pub";
  home.file.".ssh/idols-ai_id_ed25519.pub".source = "${mysecrets}/public/idols-ai_id_ed25519.pub";
  home.file.".ssh/wsl-y9000p2025_id_rsa.pub".source = "${mysecrets}/public/idols-ai_id_rsa.pub";
  home.file.".ssh/wsl-y9000p2025_id_ed25519.pub".source =
    "${mysecrets}/public/idols-ai_id_ed25519.pub";

  programs.ssh = {
    enable = true;

    enableDefaultConfig = false;
    settings."*" = {
      ForwardAgent = false;
      AddKeysToAgent = "yes";
      Compression = true;
      ServerAliveInterval = 0;
      ServerAliveCountMax = 3;
      HashKnownHosts = false;
      UserKnownHostsFile = "~/.ssh/known_hosts";
      ControlMaster = "no";
      ControlPath = "~/.ssh/master-%r@%n:%p";
      ControlPersist = "no";
    };

    settings = {
      "github.com" = {
        # avoid clash fake-IP6 hang, see modules/nixos/desktop/networking/clash-verge.nix
        AddressFamily = "inet";
        HostName = "ssh.github.com";
        Port = 443;
        User = "git";
        IdentitiesOnly = true;
      };

      "192.168.*" = {
        ForwardAgent = true;
        IdentityFile = "/etc/agenix/ssh-key-romantic";
        IdentitiesOnly = true;
      };
    };
  };

  # TODO: better way to do this?
  # https://github.com/nix-community/home-manager/issues/322#issuecomment-3655046795
  home.activation.fixSshConfigPermissions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.ssh"
    run chmod 700 "$HOME/.ssh"

    if [ -L "$HOME/.ssh/config" ]; then
      src="$(readlink -f "$HOME/.ssh/config")"
      if [ -f "$src" ]; then
        run rm -f "$HOME/.ssh/config"
        run install -m600 "$src" "$HOME/.ssh/config"
      fi
    fi
  '';
}
