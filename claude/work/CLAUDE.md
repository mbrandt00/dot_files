# User-level instructions

## Sidebar filing (Claude desktop app)

Only sessions started under `~/personal` (any subdirectory) file themselves in the Code-tab sidebar; every other session skips this whole section. The sidebar shows who has the ball. There are five sections:

- **Needs you**: the turn ends with a question, a choice or an approval for the user, or the work is blocked on the user.
- **Working**: Claude, CI, a deploy, a reviewer or another session has the work. The user has nothing to do yet.
- **Done**: the task is finished and nothing is pending. The next "clean up claude app" run archives it.
- **Later**: only when the user says to park the work.
- **Stale**: a Later session idle for more than 7 days. Only the "clean up claude app" run files here; a session never files itself as Stale.

If the session is in Later or Stale and the user has not asked to resume the work, leave it in Later. Before the turn ends, call `mcp__ccd_sidebar__move_sessions` with `session_ids: ["self"]` and the right `section_id` (load it with ToolSearch first). Do this in the same message as `wrap_up`, or before the closing message. A Stop hook (`~/.claude/hooks/sidebar-file-check.py`, which also holds the section ids) blocks the stop once if this call is missing. Subagents do not file themselves.

## Context compaction

Auto-compaction is capped at 600K tokens (`modelSettings.claude-opus-5-5.autoCompactWindow` in `~/.claude/settings.json`). That cap is a backstop for long tasks, not the normal compaction point. Compaction should happen between tasks instead.

You cannot run `/compact` or `/clear` yourself. So when you finish a task and the conversation is large (roughly 200K tokens or more), end your closing message with a one-line suggestion to run `/compact <focus on what comes next>`, or `/clear` if the next task is unrelated. Do not suggest it mid-task or after a small exchange.

## Session titles (Claude desktop app, `~/personal` only)

Keep the session title in step with the work: rename it with `set_session_title` on `"self"` when a plan is accepted or the scope moves on, as an outcome in 3 to 6 words. A title that has stayed the same across days is a smell: the session should be compacted or cleared. A Stop hook (`~/.claude/hooks/session-title-sync.py`, which holds the thresholds: plan accepted, 25+ turns or 200K+ tokens, or user turns on 2+ local dates) blocks the stop once when a check is due; `--audit` reports every live session.
