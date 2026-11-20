#!/usr/bin/env python3 -I
"""Stop hook: keep a Claude desktop session's title in step with its work.

A session title is set once, from the first prompt, and then drifts. This hook
watches for three moments when the title should be checked:

- plan:  this turn accepted a plan (ExitPlanMode), so the scope is now known;
- long:  25+ user turns, or 200K+ tokens of context, under the same title;
- days:  the same title has carried user turns on two or more local dates.
         This is the smell: the session should also be compacted or cleared.

When one fires, the hook blocks the stop once and asks Claude to compare the
title with the work, rename it with set_session_title if it is stale, and (for
"days", or "long" at the end of a task) suggest /compact or /clear.

Title age comes from the desktop app's session file
(~/Library/Application Support/Claude/claude-code-sessions/*/*/local_*.json),
which the app updates as soon as a title changes. The hook keeps a small state
file per session in ~/.claude/state/session-title-sync/ with the title it last
saw and when that title started.

Exits 0 (allow stop) when: the stop is a re-run after a block, the session is
not in the desktop app or not under ~/personal, it is a scheduled-task
session, the turn already renamed the session, or a nudge for the same title
ran earlier today and fewer than 15 turns have passed.

Run `session-title-sync.py --audit` for a read-only report over every live
session (the claude-app-cleanup skill uses it for its title step).
"""

import datetime as dt
import glob
import json
import os
import re
import sys

LONG_TURNS = 25
LONG_TOKENS = 200_000
RENUDGE_TURNS = 15
MIN_DAYS_AGE_MS = 12 * 3600 * 1000  # a late-night session past midnight is not "days"

RENAME_TOOL = "mcp__ccd_session_mgmt__set_session_title"
PLAN_TOOL = "ExitPlanMode"

HOME = os.path.expanduser("~")
PERSONAL_DIR = os.path.realpath(os.path.join(HOME, "personal"))
META_ROOT = os.environ.get(
    "SESSION_TITLE_SYNC_META_ROOT",
    os.path.join(HOME, "Library/Application Support/Claude/claude-code-sessions"),
)
STATE_DIR = os.environ.get(
    "SESSION_TITLE_SYNC_STATE_DIR",
    os.path.join(HOME, ".claude/state/session-title-sync"),
)
PROJECTS_DIR = os.path.join(HOME, ".claude/projects")

# User-role entries that are app or harness events, not the user typing.
EVENT_PREFIXES = (
    "<side-sessions-event>",
    "<ci-monitor-event>",
    "<task-notification>",
    "<command-name>",
    "<local-command-",
    "<system-reminder>",  # an unclosed reminder
)
REMINDER_RE = re.compile(r"<system-reminder>.*?</system-reminder>", re.DOTALL)


def now_ms():
    override = os.environ.get("SESSION_TITLE_SYNC_NOW_MS")
    return int(override) if override else int(dt.datetime.now().timestamp() * 1000)


def local_date(ms):
    """Local calendar date. Transcript timestamps are UTC; never bucket by them."""
    return dt.datetime.fromtimestamp(ms / 1000).date()


def iso_to_ms(value):
    try:
        return int(
            dt.datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp() * 1000
        )
    except (AttributeError, ValueError):
        return None


def started_in_personal(path):
    path = os.path.realpath(path or "")
    return path == PERSONAL_DIR or path.startswith(PERSONAL_DIR + os.sep)


# ---------------------------------------------------------------- transcript


def is_user_turn(entry):
    if (
        entry.get("type") != "user"
        or entry.get("isMeta")
        or entry.get("isCompactSummary")
    ):
        return False
    content = entry.get("message", {}).get("content")
    if isinstance(content, list):
        if any(isinstance(b, dict) and b.get("type") == "tool_result" for b in content):
            return False
        texts = [
            b.get("text", "")
            for b in content
            if isinstance(b, dict) and b.get("type") == "text"
        ]
    elif isinstance(content, str):
        texts = [content]
    else:
        return False
    # The app puts <system-reminder> blocks before the user's own words, in the
    # same message. Strip them; the turn is real if any user text is left.
    for text in texts:
        text = REMINDER_RE.sub("", text).strip()
        if text and not text.startswith(EVENT_PREFIXES):
            return True
    return False


def read_transcript(path):
    """Return user-turn times, rename times, this turn's tool names, last context size."""
    user_turns = []  # ms of each real user message
    rename_times = []  # ms of each set_session_title on "self"
    turn_tools = set()  # tool names used since the last user message
    turn_renamed = False
    context_tokens = 0
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if '"user"' not in line and '"assistant"' not in line:
                continue
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            ts = iso_to_ms(entry.get("timestamp"))
            if is_user_turn(entry):
                if ts:
                    user_turns.append(ts)
                turn_tools = set()
                turn_renamed = False
                continue
            if entry.get("type") != "assistant":
                continue
            message = entry.get("message", {})
            usage = message.get("usage") or {}
            size = sum(
                usage.get(k) or 0
                for k in (
                    "input_tokens",
                    "cache_creation_input_tokens",
                    "cache_read_input_tokens",
                )
            )
            if size and not entry.get("isSidechain"):
                context_tokens = size
            for block in message.get("content", []) or []:
                if not isinstance(block, dict) or block.get("type") != "tool_use":
                    continue
                name = block.get("name")
                turn_tools.add(name)
                if (
                    name == RENAME_TOOL
                    and (block.get("input") or {}).get("session_id") == "self"
                ):
                    turn_renamed = True
                    if ts:
                        rename_times.append(ts)
    return {
        "user_turns": user_turns,
        "rename_times": rename_times,
        "turn_tools": turn_tools,
        "turn_renamed": turn_renamed,
        "context_tokens": context_tokens,
    }


def find_transcript(cli_id):
    hits = glob.glob(os.path.join(PROJECTS_DIR, "*", f"{cli_id}.jsonl"))
    return max(hits, key=os.path.getmtime) if hits else None


# ------------------------------------------------------------ app metadata


def load_json(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def all_meta_paths():
    return glob.glob(os.path.join(META_ROOT, "*", "*", "local_*.json"))


def find_meta(cli_id):
    """The app's session file for this CLI session, via a cached path."""
    index_path = os.path.join(STATE_DIR, "_index.json")
    index = load_json(index_path) or {}
    cached = index.get(cli_id)
    if cached:
        meta = load_json(cached)
        if meta and meta.get("cliSessionId") == cli_id:
            return meta
    for path in all_meta_paths():
        meta = load_json(path)
        if meta and meta.get("cliSessionId") == cli_id:
            index[cli_id] = path
            write_json(index_path, index)
            return meta
    return None


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=1)
    os.replace(tmp, path)


def is_tracked(meta):
    return bool(
        meta
        and not meta.get("isArchived")
        and not meta.get("scheduledTaskId")
        and meta.get("titleSource") is not None
        and meta.get("title")
    )


# ------------------------------------------------------------ title age


def title_since(meta, transcript, state, now):
    """When the current title started, and whether that time is known or a guess."""
    title = meta.get("title")
    if state and state.get("title") == title and state.get("since"):
        return state["since"], True
    if meta.get("titleSource") == "auto" and not meta.get("titleTurn"):
        return meta.get("createdAt") or now, True
    if meta.get("titleSource") == "tool" and transcript["rename_times"]:
        return transcript["rename_times"][-1], True
    # Renamed by the user, or by another session: first time this hook sees it.
    return now, False


def assess(meta, transcript, since, now):
    turns = [t for t in transcript["user_turns"] if t >= since]
    dates = sorted({local_date(t) for t in turns})
    today = local_date(now)
    days = (
        len(dates) >= 2 and local_date(since) < today and now - since >= MIN_DAYS_AGE_MS
    )
    long_ = len(turns) >= LONG_TURNS or transcript["context_tokens"] >= LONG_TOKENS
    plan = PLAN_TOOL in transcript["turn_tools"]
    user_title = meta.get("titleSource") == "user"
    triggers = []
    if plan and not user_title:
        triggers.append("plan")
    if long_ and not user_title:
        triggers.append("long")
    if days:
        triggers.append("days")
    return {
        "turns": len(turns),
        "dates": dates,
        "context_tokens": transcript["context_tokens"],
        "triggers": triggers,
        "user_title": user_title,
    }


def recently_nudged(state, title, turns, now, plan):
    nudge = (state or {}).get("nudge") or {}
    if plan or nudge.get("title") != title:
        return False
    if nudge.get("date") != local_date(now).isoformat():
        return False
    return turns - (nudge.get("turns") or 0) < RENUDGE_TURNS


def fmt_date(ms):
    return dt.datetime.fromtimestamp(ms / 1000).strftime("%a %-d %b")


def build_reason(meta, result, since):
    title = meta.get("title")
    why = {
        "plan": "this turn accepted a plan, so the scope is now set",
        "long": f"{result['turns']} turns and ~{result['context_tokens'] // 1000}K tokens of context under one title",
        "days": f"the title has stayed the same across {len(result['dates'])} days (since {fmt_date(since)})",
    }
    lines = [
        "Session title sync (in addition to any sidebar filing the Stop hooks ask for): "
        + "; ".join(why[t] for t in result["triggers"])
        + ".",
        f'1. Compare the title "{title}" with what this session is about now. If it names the '
        "opening question, an earlier scope or a finished step, rename it: load "
        f'{RENAME_TOOL} with ToolSearch if needed and call it with session_id "self" and an '
        'outcome title of 3 to 6 words (for example "Fix PDF crop on Recents tiles"). If the '
        "title still fits, do not rename.",
    ]
    if result["user_title"]:
        lines.append(
            "   The user set this title, so a rename asks them to approve it. Rename only if it is clearly stale."
        )
    if "days" in result["triggers"]:
        lines.append(
            f"2. This session spans {len(result['dates'])} days of work. Add one line telling the user, and "
            "suggest `/compact <focus on what comes next>` if the work continues, or `/clear` (or a new "
            "session) if the next task is unrelated."
        )
    elif "long" in result["triggers"]:
        lines.append(
            "2. If the task is finished, add one line suggesting `/compact <focus on what comes next>`, or "
            "`/clear` if the next task is unrelated. Skip it mid-task."
        )
    lines.append(
        "Make only these calls and that one line. Do not repeat or change your answer to the user."
    )
    return "\n".join(lines)


# ------------------------------------------------------------ entry points


def hook(data):
    if data.get("stop_hook_active"):
        return None
    if os.environ.get("CLAUDE_CODE_ENTRYPOINT") != "claude-desktop":
        return None
    if not started_in_personal(os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd")):
        return None
    cli_id = data.get("session_id")
    path = data.get("transcript_path")
    if not cli_id or not path or not os.path.exists(path):
        return None
    meta = find_meta(cli_id)
    if not is_tracked(meta):
        return None
    now = now_ms()
    transcript = read_transcript(path)
    state_path = os.path.join(STATE_DIR, f"{meta['sessionId']}.json")
    state = load_json(state_path) or {}
    title = meta["title"]
    since, _ = title_since(meta, transcript, state, now)
    if state.get("title") != title:
        state = {"title": title, "since": since}
    result = assess(meta, transcript, since, now)

    reason = None
    if (
        result["triggers"]
        and not transcript["turn_renamed"]
        and not recently_nudged(
            state, title, result["turns"], now, "plan" in result["triggers"]
        )
    ):
        reason = build_reason(meta, result, since)
        state["nudge"] = {
            "title": title,
            "date": local_date(now).isoformat(),
            "turns": result["turns"],
            "triggers": result["triggers"],
        }
    write_json(state_path, state)
    return reason


def audit(as_json):
    now = now_ms()
    rows = []
    for path in all_meta_paths():
        meta = load_json(path)
        if not is_tracked(meta) or not started_in_personal(
            meta.get("originCwd") or meta.get("cwd")
        ):
            continue
        transcript_path = find_transcript(meta.get("cliSessionId", ""))
        if not transcript_path:
            continue
        transcript = read_transcript(transcript_path)
        state = load_json(os.path.join(STATE_DIR, f"{meta['sessionId']}.json"))
        since, known = title_since(meta, transcript, state, now)
        if not known:
            since = meta.get("createdAt") or now  # upper bound on the title's age
        result = assess(meta, transcript, since, now)
        rows.append(
            {
                "sessionId": meta["sessionId"],
                "title": meta["title"],
                "titleSource": meta.get("titleSource"),
                "since": dt.datetime.fromtimestamp(since / 1000).isoformat(
                    timespec="minutes"
                ),
                "sinceKnown": known,
                "lastActivity": dt.datetime.fromtimestamp(
                    (meta.get("lastActivityAt") or 0) / 1000
                ).isoformat(timespec="minutes"),
                "days": len(result["dates"]),
                "turns": result["turns"],
                "contextK": result["context_tokens"] // 1000,
                "flags": [t for t in result["triggers"] if t != "plan"],
            }
        )
    rows.sort(key=lambda r: r["lastActivity"], reverse=True)
    if as_json:
        print(json.dumps(rows, indent=1))
        return
    for r in rows:
        flags = ",".join(r["flags"]) or "-"
        since = r["since"][5:16].replace("T", " ") + ("" if r["sinceKnown"] else "?")
        print(
            f"{flags:<10} {r['days']:>2}d {r['turns']:>4}t {r['contextK']:>4}K  since {since:<13} "
            f"{r['titleSource']:<5} {r['title'][:48]:<48} {r['sessionId']}"
        )


def main(argv):
    if "--audit" in argv:
        audit("--json" in argv)
        return 0
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return 0
    try:
        reason = hook(data)
    except OSError:
        return 0
    if reason:
        print(json.dumps({"decision": "block", "reason": reason}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
