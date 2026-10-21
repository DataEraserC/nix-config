#!/usr/bin/env bash
# Run one AI agent / IDE under bubblewrap with a per-account state directory.
#
# Inputs come from the environment only, so this file carries no nix
# substitution:
#   AGENT_ACCT_ROOT  account store (default: ~/.local/state/agent-accounts)
# bubblewrap and coreutils are on PATH via the wrapper's runtimeInputs.
#
# Each app keeps its state in a path hardcoded under $HOME, with no upstream
# switch that moves it, so the per-account directories are bind-mounted over the
# real paths:
#
#   codebuddy   ~/.codebuddy, ~/.local/share/CodeBuddyExtension
#   codearts    ~/.codeartsdoer (its launcher exports these paths unconditionally)
#   workbuddy   ~/.workbuddy, ~/.sheetagent, ~/WorkBuddy, the shared Tencent auth
#   lobsterai   ~/.config/LobsterAI, ~/lobsterai (it overwrites --user-data-dir)
#   trae-cn     ~/.trae-cn, ~/.config/Trae CN
#   trae        ~/.trae, ~/.config/Trae
#
# The shared Tencent auth (codebuddy + workbuddy) is built from os.homedir(), so
# no environment variable reaches it; mounting over each path redirects all of
# them the same way, without patching or wrapping any package.
#
# Usage
#   agent-acct <app> <account> [args...]
#   agent-acct codebuddy work
#   agent-acct trae-cn 1
set -euo pipefail

case "${1:-}" in
  -h | --help | "")
    cat <<'EOF'
usage: agent-acct <app> <account> [args...]

apps: codebuddy codearts workbuddy lobsterai trae-cn trae

State goes to ~/.local/state/agent-accounts/<app>/<account>; the directory
you start the command in stays available at its real path.
EOF
    exit 2
    ;;
esac

app=$1
if [ $# -lt 2 ]; then
  echo "agent-acct: missing <account> for $app" >&2
  exit 2
fi
account=$2
shift 2

case $app in
  codebuddy) paths=(.codebuddy .local/share/CodeBuddyExtension) ;;
  codearts) paths=(.codeartsdoer) ;;
  workbuddy) paths=(.workbuddy .sheetagent WorkBuddy .local/share/CodeBuddyExtension) ;;
  lobsterai) paths=(.config/LobsterAI lobsterai) ;;
  trae-cn) paths=(.trae-cn ".config/Trae CN") ;;
  trae) paths=(.trae ".config/Trae") ;;
  *)
    echo "agent-acct: unknown app: $app" >&2
    exit 2
    ;;
esac

bin=$(command -v "$app" || true)
if [ -z "$bin" ]; then
  echo "agent-acct: $app is not installed on this host" >&2
  exit 127
fi

root=${AGENT_ACCT_ROOT:-$HOME/.local/state/agent-accounts}
dir=$root/$app/$account
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
# before the account paths: started from $HOME (a plain shell, or a desktop
# entry, which both run in $HOME), a later $HOME bind would cover every account
# mount and the app would open the real profile instead.
cwd=()
case $PWD/ in
  "$HOME"/*) ;;
  *) cwd=(--bind "$PWD" "$PWD") ;;
esac

# No --unshare-pid: Electron names its single-instance lock "<host>-<pid>", and
# inside a PID namespace that pid is always 2, which the next launch reads as a
# live instance (pid 2 is kthreadd on the host) and exits as if another window
# owned the account.
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
  --setenv AGENT_ACCOUNT "$app/$account" \
  "${runtime[@]}" \
  -- "$bin" "$@"
