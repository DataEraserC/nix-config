#!/usr/bin/env bash
# office-render <file> [outdir] [dpi] - render an Office document to per-page
# PNG images: headless LibreOffice -> PDF -> pdftoppm.
#
# Packaged by modules/nixos/base/custom/ai/office-tools/default.nix via
# writeShellApplication, which prepends `set -euo pipefail`, shellcheck and a
# PATH containing soffice / pdftoppm / coreutils. No Nix interpolation happens
# in this file: every runtime value is a script argument or computed here.
set -o errexit
set -o nounset
set -o pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  echo "usage: office-render <file> [outdir] [dpi]" >&2
  exit 1
fi
file=$1
outdir=${2:-.}
dpi=${3:-100}
if [ ! -f "$file" ]; then
  echo "office-render: no such file: $file" >&2
  exit 1
fi
case "$dpi" in
  "" | *[!0-9]*)
    echo "office-render: dpi must be a positive integer, got: $dpi" >&2
    exit 1
    ;;
esac
stem=$(basename "$file")
stem=${stem%.*}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$outdir"
# Fresh UserInstallation profile per invocation so concurrent runs (parallel
# agents) never fight over the same LibreOffice profile lock; the intermediate
# PDF stays in $work and is removed on exit.
soffice -env:UserInstallation="file://$work/profile" \
  --headless --norestore --convert-to pdf --outdir "$work" "$file"
if [ ! -f "$work/$stem.pdf" ]; then
  echo "office-render: LibreOffice did not produce $stem.pdf" >&2
  exit 1
fi
pdftoppm -png -r "$dpi" "$work/$stem.pdf" "$outdir/$stem"
for png in "$outdir/$stem"*.png; do
  [ -e "$png" ] || continue
  realpath "$png"
done
