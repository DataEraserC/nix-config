# Downstream security-key notes

Fork-specific differences from [security-keys.md](./security-keys.md) live here so the upstream
procedure remains byte-identical.

## Git commit signing

Desktop Git configuration selects the exact OpenPGP signing subkey `8A24187A88B7F2B4!`. The trailing
`!` is significant: Git passes the value unchanged to GPG, where it prevents GPG from selecting the
unusable primary key or another subkey.

Human desktop commits remain signed by default. Agent commits may explicitly use
`git commit --no-gpg-sign`; this does not change the user's persistent Git configuration. The
existing `~/work` conditional include also leaves work commits unsigned.
