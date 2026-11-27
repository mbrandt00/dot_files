#!/usr/bin/env bash
# tmux prefix+e: flip between the window's Claude pane and its nvim pane, splitting nvim open in the
# session's worktree when there is none. -Z keeps a zoomed window zoomed on the pane it lands on.
# Usage (from tmux.conf): run-shell "editor-toggle.sh PANE DIR"
pane=$1 dir=$2
panes=$(tmux list-panes -t "$pane" -F '#{pane_id} #{pane_current_command}')
nvim=$(awk '$2 == "nvim" {print $1; exit}' <<<"$panes")
claude=$(awk '$2 ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ {print $1; exit}' <<<"$panes")
# Without a Claude pane, nvim flips back to the window's first other pane.
[[ -z $claude ]] && claude=$(awk -v n="$nvim" '$1 != n {print $1; exit}' <<<"$panes")

if [[ -z $nvim ]]; then
  zoom=()
  [[ $(tmux display -p -t "$pane" '#{window_zoomed_flag}') == 1 ]] && zoom=(-Z)
  tmux split-window -h "${zoom[@]}" -t "$pane" -c "$dir" nvim
elif [[ $pane == "$nvim" ]]; then
  [[ -n $claude ]] && tmux select-pane -Z -t "$claude"
else
  tmux select-pane -Z -t "$nvim"
fi
