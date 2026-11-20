#!/usr/bin/env bash
# Live pueue queue view for the tmux popup. One line per task, truncated to popup width.
# TIME column: runtime for running tasks, wait so far for queued, total duration for done.
# Running tasks also show the last line of their output. Press q to close.
LOG_DIR="$HOME/Library/Application Support/pueue/task_logs"

# Last non-blank output line of a task, with ANSI codes and \r progress redraws stripped.
last_line() {
  tail -c 8192 "$LOG_DIR/$1.log" 2>/dev/null \
    | tr '\r' '\n' \
    | sed -E $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g' \
    | grep -v '^[[:space:]]*$' | tail -n 1
}

render() {
  local json tails id
  json=$(pueue status --json 2>/dev/null) || { echo "pueue daemon not reachable"; return; }
  tails='{}'
  for id in $(jq -r '.tasks[] | select(.status | has("Running")) | .id' <<<"$json"); do
    tails=$(jq --arg id "$id" --arg line "$(last_line "$id")" '. + {($id): $line}' <<<"$tails")
  done
  jq -r --argjson cols "$(tput cols)" --argjson tails "$tails" '
    def trunc($n): if length > $n then .[0:$n-1] + "…" else . end;
    def pad($n): tostring | trunc($n) | . + (" " * ($n - length));
    def color($c): "\u001b[\($c)m\(.)\u001b[0m";
    # "2026-10-03T18:52:09.98-06:00" -> unix epoch
    def epoch: (.[0:19] + "Z" | fromdateiso8601)
               - ((if .[-6:-5] == "-" then -1 else 1 end)
                  * ((.[-5:-3] | tonumber) * 3600 + (.[-2:] | tonumber) * 60));
    def dur: floor | if . < 60 then "\(.)s"
                     elif . < 3600 then "\(. / 60 | floor)m\(. % 60 | tostring | if length < 2 then "0" + . else . end)s"
                     else "\(. / 3600 | floor)h\(. % 3600 / 60 | floor | tostring | if length < 2 then "0" + . else . end)m" end;
    def order: {"Running": 0, "Paused": 1, "Queued": 2, "Stashed": 3, "Locked": 4, "Done": 5}[.] // 9;

    now as $now
    | .groups as $groups
    | [.tasks[] | . + {state: (.status | keys[0])} | . + {info: .status[.state]}] as $all
    | ([$all[] | select(.state == "Running")] | length) as $nrun
    | ([$all[] | select(.state == "Queued")] | length) as $nq
    | ([$all[] | select(.state == "Done" and .info.result != "Success")] | length) as $nfail
    | ("ID   STATE      TIME    TASK" | color("2")),
      ($all | group_by(.group)[] as $tasks
       | ($tasks[0].group) as $g
       # Queued tasks run highest priority first, then lowest id.
       | ($tasks | sort_by((.state | order), -.priority, .id)) as $sorted
       | ([$sorted[] | select(.state == "Queued") | .id]) as $qids
       | "",
         ("\($g)  (\($groups[$g].parallel_tasks) parallel, \($groups[$g].status | ascii_downcase))" | color("1")),
         ($sorted[] | . as $t
          | (if .state == "Done" then
               (.info.result | if . == "Success" then "ok" elif type == "object" then "\(keys[0] | ascii_downcase) \(.[keys[0]] // "")" else ascii_downcase end)
             elif .state == "Queued" then "queued \($qids | index($t.id) + 1)"
             else .state | ascii_downcase end) as $st
          | (if .state == "Running" or .state == "Paused" then $now - (.info.start | epoch)
             elif .state == "Queued" then $now - (.info.enqueued_at | epoch)
             elif .state == "Done" and .info.start then (.info.end | epoch) - (.info.start | epoch)
             else null end) as $secs
          | (if (.dependencies | length) > 0 then "after #\(.dependencies | map(tostring) | join(",#")) " else "" end) as $deps
          | ("\(.id | pad(4)) \($st | pad(10)) \(if $secs then ($secs | dur) else "" end | pad(7)) \($deps)\(.label // .command)" | trunc($cols))
          | if $t.state == "Running" then color("32")
            elif $st == "ok" then color("2")
            elif $t.state == "Done" then color("31")
            elif $t.state == "Queued" then (if $deps != "" then color("33") else . end)
            else color("33") end,
            (if $t.state == "Running" and ($tails[$t.id | tostring] // "") != "" then
               ("     └ " + $tails[$t.id | tostring] | trunc($cols) | color("2")) else empty end))),
      "",
      ("\($nrun) running · \($nq) queued · \($nfail) failed    updated \(now | localtime | strftime("%H:%M:%S"))" | color("2"))
  ' <<<"$json"
}

tput civis; trap 'tput cnorm' EXIT
# Ctrl-C stops `pueue follow` but not this loop (a function trap is reset to default in children).
trap ':' INT
clear
while :; do
  out=$(render)
  tput cup 0 0
  printf '%s\n\033[2m(q close · f follow running task)\033[0m' "$out"
  tput ed
  if read -rs -t 1 -n 1 key; then
    case $key in
      q) break ;;
      f) clear; tput cnorm; echo -e "\033[2m(ctrl-c to return)\033[0m"; pueue follow; sleep 1; tput civis; clear ;;
    esac
  fi
done
