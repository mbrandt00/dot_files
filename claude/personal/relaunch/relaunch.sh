#!/bin/bash
# Waits for the usage reset (or HH:MM), then restarts every pane in queue/ fresh from its handoff.
# Usage: relaunch.sh [HH:MM]   (default: usage.json resets_at + 2 min)
dir="$HOME/.claude-personal/relaunch"
LOG="$dir/relaunch.log"
echo $$ >"$dir/relaunch.pid"
trap 'rm -f "$dir/relaunch.pid"' EXIT
if [[ -n ${1:-} ]]; then
  target=$(date -j -f "%Y-%m-%d %H:%M" "$(date +%Y-%m-%d) $1" +%s)
  (( target <= $(date +%s) )) && target=$((target + 86400))
else
  resets=$(jq -r '.resets_at // 0' "$dir/usage.json" 2>/dev/null || echo 0)
  (( resets > $(date +%s) )) || { echo "$(date '+%F %T') no future reset in usage.json; pass HH:MM" >>"$LOG"; exit 1; }
  target=$((resets + 120))
fi
echo "$(date '+%F %T') scheduled for $(date -r "$target" '+%F %H:%M')" >>"$LOG"
while (( $(date +%s) < target )); do sleep 30; done
echo "$(date '+%F %T') start" >>"$LOG"

relaunch() { # pane cwd prompt
  local pane=$1 cwd=$2 prompt=$3
  if ! tmux display -p -t "$pane" '#{pane_id}' >/dev/null 2>&1; then
    echo "$pane: pane gone, skipped" >>"$LOG"; return 1; fi
  for _ in 1 2 3 4; do
    [[ $(tmux display -p -t "$pane" '#{pane_current_command}') == zsh ]] && break
    tmux send-keys -t "$pane" C-c; sleep 0.4; tmux send-keys -t "$pane" C-c; sleep 0.4; tmux send-keys -t "$pane" C-c; sleep 3
  done
  if [[ $(tmux display -p -t "$pane" '#{pane_current_command}') != zsh ]]; then
    echo "$pane: claude did not exit, skipped" >>"$LOG"; return 1; fi
  tmux send-keys -t "$pane" "cd $cwd && CLAUDE_CONFIG_DIR=~/.claude-personal ~/.local/bin/claude '$prompt'" Enter
  # oh-my-zsh dotenv plugin prompts on cd; decline so the claude command proceeds.
  for _ in $(seq 1 20); do
    if tmux capture-pane -p -t "$pane" | tail -5 | grep -q "dotenv: found '.env' file"; then
      tmux send-keys -t "$pane" n Enter; echo "$pane: answered dotenv prompt" >>"$LOG"; break
    fi
    [[ $(tmux display -p -t "$pane" '#{pane_current_command}') != zsh ]] && break
    sleep 0.5
  done
  echo "$pane: relaunched in $cwd" >>"$LOG"
}

for f in "$dir"/queue/*.json; do
  [[ -e $f ]] || continue
  relaunch "$(jq -r .pane "$f")" "$(jq -r .cwd "$f")" "$(jq -r .prompt "$f")"
  mv "$f" "$dir/queue/done/$(date +%Y%m%d-%H%M)-$(basename "$f")"
done
echo "$(date '+%F %T') done" >>"$LOG"
