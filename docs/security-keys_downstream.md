# Downstream security-key notes

Fork-specific differences from [security-keys.md](./security-keys.md) live here so the upstream
procedure remains byte-identical.

## No CanoKey downstream

The fork owns no CanoKey, so [security-keys.md](./security-keys.md) describes upstream's hardware
only: its enrollment, touch and recovery procedures do not apply here.

- `canokeySshKeys`, `canokeyU2fKeys` and `secondaryAuthorizedKeys` in
  [vars/default.nix](../vars/default.nix) are empty. pam_rssh
  (`modules/nixos/server/ssh-agent-sudo.nix`) therefore trusts no key, so sudo over SSH falls back
  to the password, and `modules.desktop.canokey` stays inert.
- Every host carries its own passphrase-protected key pair, named after itself:
  `~/.ssh/<host>_id_ed25519` and `~/.ssh/<host>_id_rsa`. Its home module under
  [home/hosts/linux](../home/hosts/linux) sets `programs.ssh.settings."*".IdentityFile`, so the
  shared [ssh.nix](../home/base/tui/ssh.nix) stays host-agnostic. `mainSshAuthorizedKeys` lists the
  fork's devices; upstream's `canokey-tea` / `canokey-moe` handles do not exist here.
- Public keys are not secret, so every device installs the whole `secrets/public/` set — `romantic`,
  `idols-ai_id_ed25519`, `idols-ai_id_rsa` — regardless of which pair it uses itself.
- `romantic` keeps its upstream name. [ssh.nix](../home/base/tui/ssh.nix) deploys
  `~/.ssh/romantic.pub`, and the `ssh-key-romantic` agenix secret under `/etc/agenix/` stays as the
  recovery copy of that ed25519 key.
- The agenix recovery copies `idols-ai_id_ed25519` and `idols-ai_id_rsa` under `/etc/agenix/` hold
  the ai machine's pair (one ed25519, one RSA). They matter because restic excludes both `~/.ssh`
  and `etc/agenix`. Downstream's former `gluttony` and `juliet-age` secrets were further copies of
  those two keys and are gone.
- Upstream's `ryan@romantic` recovery key is not authorized (`secondaryAuthorizedKeys` is empty).

## Git commit signing

Desktop Git configuration selects the exact OpenPGP signing subkey `8A24187A88B7F2B4!`. The trailing
`!` is significant: Git passes the value unchanged to GPG, where it prevents GPG from selecting the
unusable primary key or another subkey.

Human desktop commits remain signed by default. Agent commits may explicitly use
`git commit --no-gpg-sign`; this does not change the user's persistent Git configuration. The
existing `~/work` conditional include also leaves work commits unsigned.
