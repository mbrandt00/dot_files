#!/usr/bin/env bash
# register.sh <handoff-path> [prompt]: queue this tmux pane for a fresh relaunch after the usage reset.
set -euo pipefail
dir="$HOME/.claude-personal/relaunch"
handoff=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
[[ -f $handoff ]] || { echo "no such handoff: $handoff" >&2; exit 1; }
pane=${TMUX_PANE:-}
[[ -n $pane ]] || { echo "not in tmux: handoff written but cannot be auto-relaunched" >&2; exit 2; }
cwd=$(git -C "$(dirname "$handoff")" rev-parse --show-toplevel 2>/dev/null || dirname "$handoff")
prompt=${2:-"Read $handoff and resume."}
prompt=${prompt//\'/’}
jq -n --arg pane "$pane" --arg cwd "$cwd" --arg prompt "$prompt" --arg handoff "$handoff" \
  --arg session "${CLAUDE_CODE_SESSION_ID:-}" '{pane: $pane, cwd: $cwd, prompt: $prompt, handoff: $handoff, session: $session}' \
  >"$dir/queue/${pane#%}.json"
echo "queued pane $pane → $cwd"
if [[ -f $dir/relaunch.pid ]] && kill -0 "$(cat "$dir/relaunch.pid")" 2>/dev/null; then
  echo "relaunch already scheduled (pid $(cat "$dir/relaunch.pid"))"
else
  nohup caffeinate -i "$dir/relaunch.sh" >/dev/null 2>&1 &
  disown
  sleep 1
  tail -1 "$dir/relaunch.log"
fi
