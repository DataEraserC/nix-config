# Downstream workarounds & known gaps

Entries that only exist in this fork. [WORKAROUNDS.md](./WORKAROUNDS.md) tracks upstream's list and
stays identical to ryan4yin/nix-config, so syncing from upstream never conflicts on row content.

Use the same rules as upstream: the change that introduces a workaround adds a row here in the same
commit, with a concrete **removal condition**, and rows are refreshed or set to `removed` once that
condition is met. IDs use a separate `DS-` series so they can never collide with upstream's `WA-`
numbers, and a row that turns out to be generally useful should be sent upstream and then deleted
from this file.

## Workarounds

A setting that works around a bug or a hardware quirk.

| ID     | What & where                                                                                           | Why                                                                                                                                                                                                                                                                                              | Removal condition                                                                                                                                                                   | Added      | Revisit           | Status |
| ------ | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ----------------- | ------ |
| DS-001 | distrust the eMudhra roots through `security.pki.caCertificateBlacklist` — `modules/base/security.nix` | eight eMudhra intermediate CA private keys were recoverable from the certificates; their chains anchor at `emSign ECC Root CA - G3` and, for the Sectigo cross-signs, `Comodo AAA Services root`, and NixOS can only distrust trust anchors ([advisory](https://emudhra.we-have-a-problem.com/)) | Drop once the pinned nixpkgs ships nss-cacert ≥ 3.131.1 (or a ca-certificates that distrusts both roots) and both `curl https://dv-g3b*-emudhra.we-have-a-problem.com/` probes fail | 2026-10-22 | next nixpkgs bump | active |
