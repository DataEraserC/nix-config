#!/usr/bin/env bash
# notify-me: push a notification to the user's devices via ntfy(best-effort).
#
# Intended for AI coding agents(see agents/AGENTS.md) and interactive use.
# The ntfy topic is sourced at runtime from /etc/agenix/ntfy-topic.env, so no
# secret ever appears in agent prompts, logs, or this script.
#
# Usage:
#   notify-me [--title TITLE] [--tags TAGS] [--priority min|low|default|high] MESSAGE...
#
# Behavior:
#   - message body is sent as markdown(ntfy --markdown)
#   - default tags "robot"(🤖), default title = local hostname
#   - best-effort: exits 0 even when the topic is unavailable or publish fails,
#     so callers must never gate task success on it
set -uo pipefail

usage() {
  echo "Usage: notify-me [--title TITLE] [--tags TAGS] [--priority min|low|default|high] MESSAGE..." >&2
}

title=""
tags="robot"
priority="default"
msg_parts=()
while [ $# -gt 0 ]; do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --tags) tags="$2"; shift 2 ;;
    --priority) priority="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "notify-me: unknown option $1" >&2; usage; exit 1 ;;
    *) msg_parts+=("$1"); shift ;;
  esac
done
MSG="${msg_parts[*]:-}"
if [ -z "$MSG" ]; then
  usage
  exit 1
fi

topic_file=/etc/agenix/ntfy-topic.env
if [ -f "$topic_file" ]; then
  . "$topic_file"
fi
if [ -z "${NTFY_TOPIC:-}" ]; then
  echo "notify-me: ntfy topic unavailable($topic_file missing or NTFY_TOPIC empty), skip notification" >&2
  exit 0
fi

title="${title:-$(hostname 2>/dev/null || echo notification)}"

ntfy publish \
  --title "$title" \
  --tags "$tags" \
  --priority "$priority" \
  --markdown \
  "$NTFY_TOPIC" "$MSG" || echo "notify-me: ntfy publish failed" >&2
exit 0
