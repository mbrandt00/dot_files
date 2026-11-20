#!/usr/bin/env bash
# Run Claude Code's /rename in every idle Claude pane, so each tab's name catches up with its work.
# /rename only renames the session it runs in; this types it into the others.
# Skips a pane that is working or blocked, in copy mode, or has a draft in its input box.
# Usage: claude-rename-all.sh [-n] [-m]   (-n: say what it would do, send nothing; -m: report via tmux message)
dry=0 msgout=0
for a in "$@"; do case $a in -n) dry=1 ;; -m) msgout=1 ;; esac; done
sent=0 skipped=()

while IFS=$'\t' read -r pane label cmd mode state; do
  [[ $cmd =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue   # Claude shows as its version number
  [ "$mode" = 1 ] && { skipped+=("$label (copy mode)"); continue; }
  case $state in working|blocked) skipped+=("$label ($state)"); continue ;; esac

  screen=$(tmux capture-pane -p -t "$pane")
  prompt=$(grep -E '^❯' <<<"$screen" | tail -1)
  if [ -z "$prompt" ]; then skipped+=("$label (no input box)"); continue; fi
  # Claude pads ❯ with a no-break space, which [[:space:]] may not match.
  if [ -n "$(sed -E 's/^❯([[:space:]]| )*//' <<<"$prompt")" ]; then skipped+=("$label (draft)"); continue; fi

  if [ $dry = 1 ]; then echo "would rename $label"; sent=$((sent+1)); continue; fi
  grep -q -- '-- NORMAL --' <<<"$screen" && tmux send-keys -t "$pane" i
  tmux send-keys -t "$pane" -l '/rename'
  sleep 0.3   # let the slash-command menu settle before Enter
  tmux send-keys -t "$pane" Enter
  sent=$((sent+1))
done < <(tmux list-panes -a -F $'#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_command}\t#{pane_in_mode}\t#{@claude_state}')

msg="renamed $sent Claude pane(s)"
[ ${#skipped[@]} -gt 0 ] && msg+="; skipped: $(IFS=,; echo "${skipped[*]}")"
if [ $msgout = 1 ]; then tmux display-message -d 4000 "$msg"; else echo "$msg"; fi
