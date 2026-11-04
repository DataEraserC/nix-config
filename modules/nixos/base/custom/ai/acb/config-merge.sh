#!/usr/bin/env bash
# Derive the bridge's effective config from the hand-written base file plus the
# Nix-generated [notifications] fragment. The base file is never modified; an
# existing [notifications] table wins, so a manual block is not duplicated.
set -euo pipefail

base="@BASE@"
fragment="@FRAGMENT@"
out="@OUT@"

tmp="${out}.tmp.$$"
trap 'rm -f "$tmp"' EXIT

if grep -Eq '^[[:space:]]*\[notifications\][[:space:]]*(#.*)?$' "$base"; then
  cat "$base" >"$tmp"
else
  {
    cat "$base"
    printf '\n'
    cat "$fragment"
  } >"$tmp"
fi

chmod 600 "$tmp"
mv "$tmp" "$out"
trap - EXIT
