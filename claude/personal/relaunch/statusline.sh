#!/usr/bin/env bash
# statusLine wrapper: caches account usage for the handoff Stop hook, then shows the xq lane.
input=$(</dev/stdin)
dir="$HOME/.claude-personal/relaunch"
usage=$(jq -c '.rate_limits.five_hour // empty | {pct: .used_percentage, resets_at: .resets_at}' <<<"$input" 2>/dev/null)
if [[ -n $usage ]]; then
  printf '%s\n' "$usage" >"$dir/usage.json.$$" && mv -f "$dir/usage.json.$$" "$dir/usage.json"
fi
line=$(/Users/michaelbrandt/personal/Bravissimo/scripts/claude/xcode-queue-statusline.sh <<<"$input")
cwd=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input" 2>/dev/null)
branch=$(git -C "${cwd:-.}" branch --show-current 2>/dev/null)
[[ -n $branch ]] && line="\033[0;32m${branch}\033[0m · ${line}"
tl="$HOME/.claude-personal/tuneloop/data/refresh-status.json"
if [[ -f $tl ]]; then
  read -r tl_status tl_at < <(jq -r '"\(.status) \(.at)"' "$tl" 2>/dev/null)
  tl_epoch=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$tl_at" +%s 2>/dev/null || echo 0)
  if [[ $tl_status == error ]]; then
    line="${line} · \033[0;31mtuneloop ✗\033[0m"
  else
    # The sweep's timer stops while the Mac sleeps: only flag once it has been awake
    # long enough (one 30 min interval + a 15 min sweep) to have run again.
    now=$(date +%s)
    [[ $(sysctl -n kern.waketime 2>/dev/null) =~ sec\ =\ ([0-9]+) ]] && tl_wake=${BASH_REMATCH[1]} || tl_wake=0
    if (( now - tl_epoch > 7200 && now - tl_wake > 2700 )); then
      line="${line} · \033[0;33mtuneloop stale\033[0m"
    fi
  fi
fi
if [[ $usage =~ \"pct\":([0-9.]+) ]]; then
  printf "\033[0;35mpersonal\033[0m · %b · 5h %.0f%%\n" "$line" "${BASH_REMATCH[1]}"
else
  printf "\033[0;35mpersonal\033[0m · %b\n" "$line"
fi
