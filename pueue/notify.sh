#!/bin/sh
# pueue daemon callback: flash a tmux message when a task finishes.
# Args: id, group, result. The label is looked up here instead of templated into the
# callback string, so quotes in labels/commands can't break shell quoting.
id=$1 group=$2 result=$3
label=$(/opt/homebrew/bin/pueue status --json 2>/dev/null \
  | /opt/homebrew/bin/jq -r --arg id "$id" '.tasks[$id] | .label // .command' 2>/dev/null)
/opt/homebrew/bin/tmux display-message -d 5000 "pueue #$id [$group] $result: $label" 2>/dev/null
exit 0
