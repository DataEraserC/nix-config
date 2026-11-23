# Nix Configuration

Canonical language for concepts that this configuration exposes across NixOS and Home Manager.

## Language

**Mutable source**: A named content root that prefers a writable path outside the Nix store and may
have an immutable fallback. _Avoid_: Out-of-store symlink, path pool

**Managed link**: A symlink whose filesystem location is declaratively owned and reconciled across
system generations. _Avoid_: Mutable source, unmanaged link
