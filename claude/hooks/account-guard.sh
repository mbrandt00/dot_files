#!/usr/bin/env bash
# SessionStart: warn when a session runs on the wrong Claude account for its folder.
# Usage: account-guard.sh <work|personal>; each profile's settings.json passes its own name.
# Folders outside the lists below (work repos that live straight in ~) never warn.
profile=${1:?profile}
cwd=$(jq -r '.cwd // empty' 2>/dev/null)
cwd=${cwd:-$PWD}
# macOS paths are case-insensitive, so ~/Personal must still match.
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
path=$(lc "$cwd/") home=$(lc "$HOME")
case $path in
  "$home"/work/*) want=work fix="claude-work" ;;
  "$home"/personal/* | "$home"/.config/* | "$home"/.claude-personal/*)
    want=personal fix="CLAUDE_CONFIG_DIR=~/.claude-personal claude" ;;
  *) exit 0 ;;
esac
[ "$profile" = "$want" ] && exit 0
msg="Wrong Claude account: this session uses the $profile account, but ${cwd/#"$HOME"/'~'} is a $want folder. Quit and relaunch with: $fix"
jq -n --arg m "$msg" '{systemMessage: $m,
  hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ($m + " Mention this to the user in your first reply.")}}'
exit 0
