#!/usr/bin/env bash
# ===============================================================================
# Patch a Sub-Store panel dist (Sub-Store-Front-End release) at build time.
#
# The release hardcodes https://sub.store as its default API origin in TWO code
# paths (a constant, and the `|| fallback` used when the hostAPI list is empty -
# the one that actually runs on first visit) plus several i18n help texts.
# Rewrite them all to a local origin first, then promote the quote-delimited
# code-level defaults to the JS template literal
#
#   `http://${location.hostname||"127.0.0.1"}:<port>`
#
# so the panel always calls the backend on the host the page was actually
# opened with (127.0.0.1 / LAN IP / 0.0.0.0-binds / SSH tunnels). Help texts
# embed the origin unquoted and stay a readable static example. Finally touch
# sw.js: a byte-different service worker makes browsers re-precache on the next
# visit even though the hashed chunk filenames did not change.
#
# Usage: sub-store-frontend-patch.sh <dist-dir> <backend-port> <frontend-version>
#   <dist-dir>          writable copy of the release dist (the derivation $out)
#   <backend-port>      TCP port of the Sub-Store backend API (cfg.port)
#   <frontend-version>  release version, stamped into the sw.js cache marker
#
# All module values arrive as plain arguments from sub-store/default.nix instead
# of Nix string interpolation, so this file stays readable bash - including the
# JS ${...} below, which the single quotes keep literal.
# ===============================================================================
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $(basename "$0") <dist-dir> <backend-port> <frontend-version>" >&2
  exit 2
fi
dist=$1
port=$2
version=$3

if [ ! -d "$dist" ]; then
  echo "sub-store-frontend-patch: no such dist dir: $dist" >&2
  exit 2
fi
if [ ! -f "$dist/sw.js" ]; then
  echo "sub-store-frontend-patch: expected $dist/sw.js to exist" >&2
  exit 2
fi

# Static loopback origin: the sed step-1 target result and the exact quoted
# token the step-2 rewrite and the guards look for. Deliberately NOT derived
# from cfg.host - a bind address like 0.0.0.0 is not connectable from a browser.
static_origin="http://127.0.0.1:${port}"
static_token="\"${static_origin}\""                  # "http://127.0.0.1:24500"
# Regex-escaped sed pattern WITH the surrounding quotes: only quote-delimited
# occurrences (code-level defaults) may become dynamic; occurrences embedded in
# help-text sentences keep the static origin.
static_pattern=${static_token//./\\.}
# Backticks and ${...} stay literal inside the single quotes; only the port is
# spliced in by the shell.
dynamic_origin='`http://${location.hostname||"127.0.0.1"}:'"${port}"'`'

# 1) official URL -> local origin (code paths + help texts)
find "$dist" -name '*.js' -exec sed -i "s#https://sub\.store#${static_origin}#g" {} +
if grep -rFq 'https://sub.store' "$dist" --include='*.js'; then
  echo "sub-store-frontend-patch: official backend reference left over" >&2
  exit 1
fi

# 2) quote-delimited occurrences are code-level defaults -> location.hostname
#    form. Unquoted occurrences (help texts) keep the static loopback origin.
static_before=$(grep -rhoF "$static_token" "$dist" --include='*.js' | wc -l || true)
if [ "$static_before" -lt 2 ]; then
  echo "sub-store-frontend-patch: expected >= 2 quoted code defaults, found $static_before" >&2
  exit 1
fi
find "$dist" -name '*.js' -exec sed -i "s#${static_pattern}#${dynamic_origin}#g" {} +
static_after=$(grep -rhoF "$static_token" "$dist" --include='*.js' | wc -l || true)
if [ "$static_after" -ne 0 ]; then
  echo "sub-store-frontend-patch: $static_after quoted code defaults left after dynamic patch" >&2
  exit 1
fi
dyn_count=$(grep -rhoF 'location.hostname' "$dist" --include='*.js' | wc -l || true)
if [ "$dyn_count" -ne "$static_before" ]; then
  echo "sub-store-frontend-patch: dynamic defaults $dyn_count != expected $static_before" >&2
  exit 1
fi

# 3) touch sw.js: bust the service-worker precache despite unchanged chunk hashes
printf '\n// nix-patch: %s location.hostname backend\n' "$version" >> "$dist/sw.js"

echo "sub-store-frontend-patch: patched $dist - port $port, $static_before code default(s) now follow location.hostname"
