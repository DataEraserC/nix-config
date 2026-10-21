#!/usr/bin/env bash
# Run one program under bubblewrap with a per-instance state directory.
#
# This file holds no program-specific data. Nix supplies the two inputs it
# needs from modules.multi-instance:
#   MULTI_INSTANCE_SPEC  one "app|path|path..." line per program, paths relative
#                        to $HOME
#   MULTI_INSTANCE_ROOT  instance store, one directory per <app>/<instance>
# bubblewrap and coreutils are on PATH via the wrapper's runtimeInputs.
#
# Each path on the line is a location the program hardcodes under $HOME with no
# switch to move it, so the instance's directory is bind-mounted over each one.
# Mounting redirects all of them without patching or wrapping the program.
#
# Usage
#   multi-instance <app> <instance> [args...]
set -euo pipefail

spec=${MULTI_INSTANCE_SPEC:?MULTI_INSTANCE_SPEC must point at the generated spec}

# Only the first field: the program names, one per line, in file order.
list_apps() {
  while IFS='|' read -r name _; do
    echo "  $name"
  done <"$spec"
}

usage() {
  cat <<'EOF'
usage: multi-instance <app> <instance> [args...]

apps:
EOF
  list_apps
  cat <<'EOF'

Each instance keeps its state in $MULTI_INSTANCE_ROOT/<app>/<instance>; the
directory you start the command in stays available at its real path.
EOF
}

case "${1:-}" in
  -h | --help | "")
    usage
    exit 2
    ;;
esac

app=$1
if [ $# -lt 2 ]; then
  echo "multi-instance: missing <instance> for $app" >&2
  exit 2
fi
instance=$2
shift 2

line=
while IFS= read -r candidate; do
  case $candidate in
    "$app|"*)
      line=$candidate
      break
      ;;
  esac
done <"$spec"

if [ -z "$line" ]; then
  echo "multi-instance: unknown app: $app" >&2
  echo "multi-instance: known apps:" >&2
  list_apps >&2
  exit 2
fi

IFS='|' read -r -a fields <<<"$line"
paths=("${fields[@]:1}")

bin=$(command -v "$app" || true)
if [ -z "$bin" ]; then
  echo "multi-instance: $app is not installed on this host" >&2
  exit 127
fi

root=${MULTI_INSTANCE_ROOT:-$HOME/.local/state/multi-instance}
dir=$root/$app/$instance
mkdir -p "$dir"

mounts=()
for rel in "${paths[@]}"; do
  mkdir -p "$dir/$rel"
  mounts+=(--bind "$dir/$rel" "$HOME/$rel")
done

runtime=()
if [ -d "/run/user/$(id -u)" ]; then
  runtime=(--bind "/run/user/$(id -u)" "/run/user/$(id -u)")
fi

# A bind of a parent directory hides every mount made under it, so $PWD is bound
# only when it is outside $HOME: started from $HOME (a plain shell, or a desktop
# entry, which both run in $HOME), binding it again after the instance mounts
# would cover every one of them and the program would open the real profile.
cwd=()
case $PWD/ in
  "$HOME"/*) ;;
  *) cwd=(--bind "$PWD" "$PWD") ;;
esac

# No --unshare-pid: Electron names its single-instance lock "<host>-<pid>", and
# inside a PID namespace that pid is always 2, which the next launch reads as a
# live instance (pid 2 is kthreadd on the host) and exits as if another window
# owned the instance.
exec bwrap \
  --die-with-parent \
  --unshare-uts --unshare-ipc --unshare-user-try \
  --ro-bind / / \
  --proc /proc \
  --dev-bind /dev /dev \
  --bind "$HOME" "$HOME" \
  --bind /tmp /tmp \
  "${cwd[@]}" \
  "${mounts[@]}" \
  --tmpfs "$root" \
  --chdir "$PWD" \
  --setenv MULTI_INSTANCE "$app/$instance" \
  "${runtime[@]}" \
  -- "$bin" "$@"
