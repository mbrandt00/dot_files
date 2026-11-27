#!/usr/bin/env bash
# SessionStart: warn when a session runs on the wrong Claude account for its folder.
# Usage: account-guard.sh <work|personal>; each profile's settings.json passes its own name.
# The account is read from the session, not assumed from the profile: the desktop app signs in
# with its own account and only borrows ~/.claude for settings. The profile name is the
# fallback when the account can't be read.
# Folders outside the lists below (work repos that live straight in ~) never warn.
profile=${1:?profile}
cwd=$(jq -r '.cwd // empty' 2>/dev/null)
cwd=${cwd:-$PWD}
# macOS paths are case-insensitive, so ~/Personal must still match.
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
path=$(lc "$cwd/") home=$(lc "$HOME")
case $path in
  "$home"/work/*) want=work ;;
  "$home"/personal/* | "$home"/.config/* | "$home"/.claude-personal/*) want=personal ;;
  *) exit 0 ;;
esac

# The work org is the one the work profile is pinned to; any other org counts as personal.
work_org=$(jq -r '.forceLoginOrgUUID // empty' "$HOME/.claude/settings.json" 2>/dev/null)
# A host that brings its own token (the desktop app) names its org in the environment.
org=${CLAUDE_CODE_ORGANIZATION_UUID:-}
if [ -z "$org" ]; then
  if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then state=$CLAUDE_CONFIG_DIR/.claude.json; else state=$HOME/.claude.json; fi
  org=$(jq -r '.oauthAccount.organizationUuid // empty' "$state" 2>/dev/null)
fi
if [ -n "$work_org" ] && [ -n "$org" ]; then
  if [ "$org" = "$work_org" ]; then have=work; else have=personal; fi
else
  have=$profile
fi
[ "$have" = "$want" ] && exit 0

if [ "${CLAUDE_CODE_ENTRYPOINT:-}" = claude-desktop ]; then
  fix="The desktop app is signed in to the $have account; use the CLI in this folder instead (claude-$want)."
else
  fix="Quit and relaunch with: claude-$want"
fi
msg="Wrong Claude account: this session uses the $have account, but ${cwd/#"$HOME"/'~'} is a $want folder. $fix"
jq -n --arg m "$msg" '{systemMessage: $m,
  hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ($m + " Mention this to the user in your first reply.")}}'
exit 0
