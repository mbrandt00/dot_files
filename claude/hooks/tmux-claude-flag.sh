#!/usr/bin/env bash
# Record a Claude Code session's state on its tmux window; the status line colors the tab from it.
# Usage: tmux-claude-flag.sh <working|ready|blocked|idle|clear>
# ready (finished) and blocked (permission prompt) stay until your next prompt or tool call sets working.
# idle (Claude's ~60s "waiting for input" notice) turns working into ready, which covers an Esc
# interrupt, where Stop never fires; it leaves blocked alone. clear (session end) drops the state.
[ -z "$TMUX_PANE" ] && exit 0
state=${1:?state}

# A background subagent's tool calls don't mean the main session is working again.
if [ ! -t 0 ] && [ -n "$(jq -r '.agent_id // empty' 2>/dev/null)" ]; then
  exit 0
fi

case $state in
  clear) tmux set -wu -t "$TMUX_PANE" @claude_state 2>/dev/null ;;
  idle)
    [ "$(tmux show -wv -t "$TMUX_PANE" @claude_state 2>/dev/null)" = working ] || exit 0
    tmux set -w -t "$TMUX_PANE" @claude_state ready 2>/dev/null ;;
  *) tmux set -w -t "$TMUX_PANE" @claude_state "$state" 2>/dev/null ;;
esac
# A rename or a tmux-resurrect restore can switch automatic-rename off and freeze the
# tab name; drop the window override so it follows the title Claude sets again.
tmux set -wu -t "$TMUX_PANE" automatic-rename 2>/dev/null
tmux refresh-client -S 2>/dev/null
exit 0
