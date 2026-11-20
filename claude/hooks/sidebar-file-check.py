#!/usr/bin/env python3 -I
"""Stop hook: make each Claude desktop session file itself in the sidebar.

Before the turn ends, the session must move itself to the section that
describes who has the ball now. This hook checks that the current turn called
mcp__ccd_sidebar__move_sessions on "self". If not, it blocks the stop once and
tells Claude which section ids to use.

Exits 0 (allow stop) when:
- the stop is already a re-run after a block (stop_hook_active), or
- the session is not in the Claude desktop app, or
- the session was not started under ~/personal, or
- the transcript cannot be read, or
- the current turn already filed the session.
"""

import json
import os
import sys

SECTIONS = {
    "Needs you": "cg-997af100-3eb0-46b4-bd2e-ad000697cb42",
    "Working": "cg-e2dec28d-0866-4678-9563-ff2cad8038d3",
    "Later": "cg-7d2eaa3e-e689-4d87-82de-e03c9cd651fa",
    "Done": "cg-8df7d622-9518-42f2-bb25-7064b0e11a74",
    "Stale": "cg-26b577ba-ba6e-4c5a-98dc-6bdb6755eaa6",
}

MOVE_TOOL = "mcp__ccd_sidebar__move_sessions"

PERSONAL_DIR = os.path.realpath(os.path.expanduser("~/personal"))


def started_in_personal(data):
    start = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or ""
    start = os.path.realpath(start)
    return start == PERSONAL_DIR or start.startswith(PERSONAL_DIR + os.sep)


def is_real_user_message(entry):
    if entry.get("type") != "user" or entry.get("isMeta"):
        return False
    content = entry.get("message", {}).get("content")
    if isinstance(content, str):
        return True
    if isinstance(content, list):
        return not any(
            b.get("type") == "tool_result" for b in content if isinstance(b, dict)
        )
    return False


def filed_this_turn(path):
    filed = False
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if is_real_user_message(entry):
                filed = False
                continue
            if entry.get("type") != "assistant":
                continue
            for block in entry.get("message", {}).get("content", []) or []:
                if not isinstance(block, dict) or block.get("type") != "tool_use":
                    continue
                if block.get("name") != MOVE_TOOL:
                    continue
                ids = (block.get("input") or {}).get("session_ids") or []
                if "self" in ids:
                    filed = True
    return filed


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return 0
    if data.get("stop_hook_active"):
        return 0
    if os.environ.get("CLAUDE_CODE_ENTRYPOINT") != "claude-desktop":
        return 0
    if not started_in_personal(data):
        return 0
    path = data.get("transcript_path")
    if not path or not os.path.exists(path):
        return 0
    try:
        if filed_this_turn(path):
            return 0
    except OSError:
        return 0

    ids = "; ".join(f'{name} = "{sid}"' for name, sid in SECTIONS.items())
    reason = (
        "Sidebar filing: before you stop, file this session. Load "
        f"{MOVE_TOOL} with ToolSearch if needed, then call it with "
        'session_ids ["self"] and the section_id that fits:\n'
        "- Needs you: you end the turn with a question, a choice or an approval for the user, "
        "or the work is blocked on the user.\n"
        "- Working: you, CI, a deploy, a reviewer or another session has the work; "
        "the user has nothing to do yet.\n"
        "- Done: the task is finished and nothing is pending.\n"
        "- Later: only when the user said to park this work. If get_session self shows "
        "Later or Stale and the user has not asked to resume it, leave it there and skip the call.\n"
        "- Stale: never file here yourself; the cleanup skill moves Later sessions idle over 7 days.\n"
        f"Section ids: {ids}.\n"
        "Make only the calls the Stop hooks ask for. Do not repeat or change your answer to the user."
    )
    print(json.dumps({"decision": "block", "reason": reason}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
