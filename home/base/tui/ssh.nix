{
  config,
  lib,
  pkgs,
  mysecrets,
  myvars,
  ...
}:
let
  # WA-035: settings for the home LAN, which the desktop reaches over a Mesh
  # WiFi backhaul.
  lanHost = {
    # A lost first SYN must not fail the connection; a LAN handshake is ~2 ms,
    # so the connect is cut short and retried instead of hanging.
    ConnectTimeout = 1;
    ConnectionAttempts = 3;
    # One persistent master per host keeps a session (and with it the mesh's
    # forwarding entry for that peer) open, so later connections reuse it
    # instead of resolving and handshaking again. Three missed keepalives reap a
    # master whose path died.
    ControlMaster = "auto";
    ControlPersist = "30m";
    ServerAliveInterval = 15;
  };
in
{
  # Public keys are not secret: every device installs the whole set, whatever
  # its own identity is. Only the private key name differs per host (its home
  # module sets `settings."*".IdentityFile`).
  home.file.".ssh/romantic.pub".source = "${mysecrets}/public/romantic.pub";
  home.file.".ssh/idols-ai_id_ed25519.pub".source = "${mysecrets}/public/idols-ai_id_ed25519.pub";
  home.file.".ssh/idols-ai_id_rsa.pub".source = "${mysecrets}/public/idols-ai_id_rsa.pub";
  home.file.".ssh/wsl-work_id_ed25519.pub".source = "${mysecrets}/public/wsl-work_id_ed25519.pub";
  # TODO: wsl-y9000p2025's own public keys are still missing. Its distro disk is
  # not on the mounted Windows volume, so these stay disabled until we can read
  # them from ~/.ssh on that host (or from its ext4.vhdx once located).
  # home.file.".ssh/wsl-y9000p2025_id_ed25519.pub".source =
  #   "${mysecrets}/public/wsl-y9000p2025_id_ed25519.pub";
  # home.file.".ssh/wsl-y9000p2025_id_rsa.pub".source =
  #   "${mysecrets}/public/wsl-y9000p2025_id_rsa.pub";

  # The fork has no CanoKey, and each host carries its own key pair named after
  # itself (`<host>_id_ed25519` + `<host>_id_rsa`). ssh asks for the passphrase
  # once and the agent keeps it.
  programs.ssh = {
    enable = true;
    # macOS's ssh has no FIDO provider ("Cannot download keys without provider").
    package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin pkgs.openssh;

    enableDefaultConfig = false;
    # Keep this one definition: Nix merges a `settings."<pattern>"` attribute
    # path into `settings = ...` only while that value stays an attrset literal,
    # so the generated LAN patterns are merged inside it with `//` instead.
    settings = {
      "*" = {
        # IdentityFile is per host (see the comment above); ssh asks for the
        # passphrase once and the agent keeps it.
        ForwardAgent = false;
        AddKeysToAgent = "yes";
        Compression = true;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        # A connection reused within 30 s needs no new touch.
        ControlMaster = "auto";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "30s";
      };

      "github.com" = {
        # WA-028: pinned to IPv4 until the mihomo v6 fake-ip pool is proven here
        AddressFamily = "inet";
        HostName = "ssh.github.com";
        Port = 443;
        User = "git";
        IdentitiesOnly = true;
      };

      "192.168.*" = {
        ForwardAgent = true;
      }
      // lanHost;
    }
    # Aliases forward the agent like their addresses do; servers ask it for sudo
    # (modules/nixos/server/ssh-agent-sudo.nix).
    // lib.genAttrs (builtins.attrNames myvars.networking.hostsAddr) (
      _:
      {
        ForwardAgent = true;
      }
      // lanHost
    );
  };

  # Keep ~/.ssh/config a real, user-owned file rather than a /nix/store symlink.
  #
  # OpenSSH accepts a config owned by root or the invoking user, but
  # bubblewrap-based sandboxes (`--unshare-user`) expose root-owned store files
  # as `nobody`, which trips the check (`Bad owner or permissions`).  Disabling
  # the home.file entry keeps Home Manager's linker out of the way; `install`
  # writes a fresh 0600 copy on each activation.
  #
  # Linux only: macOS' Seatbelt sandbox keeps store ownership intact, so the
  # normal symlink is fine there.
  home.file.".ssh/config".enable = lib.mkIf pkgs.stdenv.hostPlatform.isLinux false;
  home.activation.sshConfigRegularFile = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run install -D -m 600 ${config.home.file.".ssh/config".source} "$HOME/.ssh/config"
    ''
  );
}
