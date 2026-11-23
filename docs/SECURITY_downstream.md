# Downstream Security Notes

This document records security boundaries introduced only by the DataEraserC fork. The upstream
security architecture remains in [SECURITY.md](./SECURITY.md).

## Shared compiler cache

On `idols-ai`, Nix build sandboxes can reach the local sccache Unix socket under `/run/sccache`. The
server runs as the pinned, unprivileged `sccache` account, accepts only Unix-domain connections, and
uses client-side mode so compilers still execute inside their original Nix sandboxes. The server
only stores and returns compiler artifacts in `/var/cache/sccache`. The current launcher is scoped
to `pkgs-cuda`'s torch NVCC calls; global Nix C/C++ compiler wrappers are not redirected. Nix
builders use auto-allocated UIDs without supplementary groups, so the known socket path is mode
`0666` behind a non-listable `0711` runtime directory. The cache directory itself remains `0770` and
invisible to builders. A root oneshot reapplies the socket mode whenever the server recreates it.

This deliberately adds a shared local build trust boundary: every local Nix sandbox—and any local
process that knows the socket path—can query or seed the cache. Do not treat a cache populated by
untrusted derivations as trusted compiler output. Stop the service and clear `/var/cache/sccache`
before rebuilding trusted outputs after an untrusted local build. The cache is not a binary
substituter and grants no binary-cache signing trust.
