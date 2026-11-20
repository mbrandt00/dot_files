#!/bin/sh
# tmux status-right segment: running/queued pueue task counts, empty when idle or daemon down.
pueue status --json 2>/dev/null | jq -r '
  [.tasks[].status | keys[0]] as $s
  | ($s | map(select(. == "Running")) | length) as $r
  | ($s | map(select(. == "Queued")) | length) as $q
  | if $r + $q > 0 then "⚙ \($r)▶ \($q)⏸ " else "" end'
