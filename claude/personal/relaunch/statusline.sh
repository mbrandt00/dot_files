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
if [[ $usage =~ \"pct\":([0-9.]+) ]]; then
  printf "\033[0;35mpersonal\033[0m · %b · 5h %.0f%%\n" "$line" "${BASH_REMATCH[1]}"
else
  printf "\033[0;35mpersonal\033[0m · %b\n" "$line"
fi
