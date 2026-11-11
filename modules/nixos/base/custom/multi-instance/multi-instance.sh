#!/usr/bin/env bash
# Run one program under bubblewrap with a per-instance state directory.
#
# This file holds no program-specific data. Nix supplies the two inputs it
# needs from modules.multi-instance:
#   MULTI_INSTANCE_SPEC  one "cli-key|executable|state-key|path|path..." line
#                        per canonical app or compatibility alias, with state
#                        paths relative to $HOME
#   MULTI_INSTANCE_ROOT  instance store, one directory per
#                        <state-key>/<instance>
# bubblewrap and coreutils are on PATH via the wrapper's runtimeInputs.
#
# Each path on the line is a location the program hardcodes under $HOME with no
# switch to move it, so the instance's directory is bind-mounted over each one.
# Mounting redirects all of them without patching or wrapping the program.
#
# One field may be prefixed with @: the program's user data directory, for
# programs whose single-instance lock is named after it. Chromium derives the
# lock socket "<sha256 of that path>-<version>-main.sock" from the string, and
# every instance sees the same string, so a second instance finds the first
# instance's socket, hands its command line over and exits, and the window that
# appears belongs to the first instance. That directory is mounted a second time
# under a per-instance path and passed as --user-data-dir, so the name differs
# while the data does not.
#
# /tmp is a fresh tmpfs per instance, not the host's: a program that derives a
# lock or socket name from a state path gets the same name in every instance —
# the path is redirected, not rewritten — so on a shared /tmp the second instance
# finds the first instance's lock and refuses to start. The X11 and X session
# manager sockets belong to the desktop session and are mounted back in.
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

Each instance keeps its state in $MULTI_INSTANCE_ROOT/<state-key>/<instance>; the
state key usually matches the app but may stay stable across an executable rename.
The directory you start the command in stays available at its real path.
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
executable=${fields[1]}
state_key=${fields[2]}
data=
paths=()
for field in "${fields[@]:3}"; do
  case $field in
    @*) data=${field#@} ;;
    *) paths+=("$field") ;;
  esac
done

bin=$(command -v "$executable" || true)
if [ -z "$bin" ]; then
  echo "multi-instance: $executable (app $app) is not installed on this host" >&2
  exit 127
fi

root=${MULTI_INSTANCE_ROOT:-$HOME/.local/state/multi-instance}
dir=$root/$state_key/$instance
mkdir -p "$dir"

mounts=()
for rel in "${paths[@]}"; do
  mkdir -p "$dir/$rel"
  mounts+=(--bind "$dir/$rel" "$HOME/$rel")
done

# The same directory under a per-instance path, for the user data directory
# whose name the program's single-instance lock is derived from; see the header.
# It is created inside the tmpfs below, so it exists nowhere on the host.
data_mounts=()
data_args=()
if [ -n "$data" ]; then
  data_mounts=(--dir "$dir/data" --bind "$dir/$data" "$dir/data")
  data_args=(--user-data-dir="$dir/data")
fi

runtime=()
if [ -d "/run/user/$(id -u)" ]; then
  runtime=(--bind "/run/user/$(id -u)" "/run/user/$(id -u)")
fi

# /tmp starts empty in the sandbox; see the header. A socket directory the
# desktop session owns is mounted back so the program can still reach its display.
tmp=(--tmpfs /tmp)
for sock in /tmp/.X11-unix /tmp/.ICE-unix; do
  if [ -d "$sock" ]; then
    tmp+=(--bind "$sock" "$sock")
  fi
done

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
  "${tmp[@]}" \
  "${cwd[@]}" \
  "${mounts[@]}" \
  --tmpfs "$root" \
  "${data_mounts[@]}" \
  --chdir "$PWD" \
  --setenv MULTI_INSTANCE "$app/$instance" \
  "${runtime[@]}" \
  -- "$bin" "${data_args[@]}" "$@"
