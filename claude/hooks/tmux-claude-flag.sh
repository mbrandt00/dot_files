#!/usr/bin/env bash
# Record a Claude Code session's state on its tmux window; the status line colors the tab from it.
# Usage: tmux-claude-flag.sh <working|ready|blocked>
# ready (finished) and blocked (permission prompt) stay until your next prompt or tool call sets working.
[ -z "$TMUX_PANE" ] && exit 0
tmux set -w -t "$TMUX_PANE" @claude_state "${1:?state}" 2>/dev/null
tmux refresh-client -S 2>/dev/null
exit 0
