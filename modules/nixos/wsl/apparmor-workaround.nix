{ lib, ... }:
# WORKAROUND: Disable AppArmor on WSL hosts.
#
# Reason:
#   nixpkgs' apparmor `includes.nix` uses an `etcRule` helper that
#   iterates over `environment.etc` entries and accesses `.source` for
#   each one (via `hasAttr path etc`).  NixOS-WSL sets
#   `environment.etc."resolv.conf".enable = false` (because WSL manages
#   resolv.conf), so the entry exists in the attrset but has no
#   `.source` value.  The `etcRule` function does not check `.enable`
#   before accessing `.source`, causing:
#
#     error: The option `environment.etc."resolv.conf".source' was
#            accessed but has no value defined.
#
#   See: nixpkgs#500104 for an upstream fix that adds `emptyValue`
#   defaults to the module system, which would resolve this class of
#   bugs generically.
#
# When to remove:
#   This workaround can be removed once ALL of the following are true:
#   1. nixpkgs lands the `emptyValue` default fix (PR #500104) or the
#      apparmor `etcRule` is patched to check `.enable` before accessing
#      `.source`.
#   2. Your flake.lock pins a nixpkgs version that includes the fix.
#
# TODO: remove this file and its import once the upstream fix is available.
{
  security.apparmor.enable = lib.mkForce false;
}
