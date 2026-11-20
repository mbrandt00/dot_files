#!/usr/bin/env bash
# Stop hook: once per usage window, past the threshold, block the stop and ask for a handoff.
threshold=${HANDOFF_THRESHOLD:-90}
dir="$HOME/.claude-personal/relaunch"
input=$(</dev/stdin)
[[ $(jq -r '.stop_hook_active // false' <<<"$input") == true ]] && exit 0
[[ -f $dir/usage.json ]] || exit 0
read -r pct resets < <(jq -r '"\(.pct // 0) \(.resets_at // 0)"' "$dir/usage.json")
sid=$(jq -r '.session_id // empty' <<<"$input")
[[ -n $sid ]] || exit 0
(( ${pct%.*} >= threshold )) || exit 0
(( resets > $(date +%s) )) || exit 0
mkdir -p "$dir/prompted"
marker="$dir/prompted/$sid-$resets"
[[ -e $marker ]] && exit 0
: >"$marker"
reset_at=$(date -r "$resets" +%H:%M)
jq -n --arg r "5-hour usage is at ${pct%.*}% (resets $reset_at). Before stopping, load the handoff skill and follow it: write this session's handoff doc and register it for relaunch. If this session has no work in progress worth resuming, say so in one line and stop instead." \
  '{decision: "block", reason: $r}'
