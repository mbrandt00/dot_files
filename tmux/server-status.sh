#!/usr/bin/env bash
# Status-bar light for the mise dev "server" session: server icon + branch, green running, red stopped,
# nothing if absent.
tmux has-session -t '=server' 2>/dev/null || exit 0
path=$(tmux show -gv @server_path 2>/dev/null)
branch=$(git -C "$path" branch --show-current 2>/dev/null)
label=${branch:-${path##*/}}
# Linear branches shorten to the ticket id; others are cut to fit beside pueue.
if [[ $label =~ ^(bs-[0-9]+) ]]; then label=${BASH_REMATCH[1]}; else label=${label:0:20}; fi
icon=$(printf '')
dead=$(tmux list-panes -s -t '=server' -F '#{pane_dead}')
if [[ $dead == *1* || $(tmux show -gv @server_state 2>/dev/null) == stopped ]]; then
  echo "#[fg=red]$icon $label"
else
  echo "#[fg=green]$icon $label"
fi
