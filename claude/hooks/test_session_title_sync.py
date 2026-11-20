"""Tests for session-title-sync.py. Run: python3 -I ~/.claude/hooks/test_session_title_sync.py"""

import datetime as dt
import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "session-title-sync.py")
CLI = "11111111-2222-3333-4444-555555555555"
LOCAL = "local_test-session"


def ms(local_dt):
    return int(local_dt.timestamp() * 1000)


def iso(local_dt):
    return local_dt.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def user(when, text="do the thing"):
    return {
        "type": "user",
        "timestamp": iso(when),
        "message": {"role": "user", "content": text},
    }


def assistant(when, tools=(), tokens=1000):
    content = [{"type": "tool_use", "name": n, "input": i} for n, i in tools]
    return {
        "type": "assistant",
        "timestamp": iso(when),
        "message": {
            "role": "assistant",
            "content": content,
            "usage": {"input_tokens": tokens},
        },
    }


class HookTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = self.tmp.name
        self.meta_dir = os.path.join(root, "meta", "a", "b")
        self.state_dir = os.path.join(root, "state")
        os.makedirs(self.meta_dir)
        self.transcript = os.path.join(root, "t.jsonl")
        self.cwd = os.path.join(os.path.expanduser("~"), "personal", "Bravissimo")
        self.now = dt.datetime(2026, 11, 11, 18, 0)

    def tearDown(self):
        self.tmp.cleanup()

    def write(
        self, entries, created, source="auto", title="Opening question", extra=None
    ):
        meta = {
            "sessionId": LOCAL,
            "cliSessionId": CLI,
            "title": title,
            "titleSource": source,
            "titleTurn": 0,
            "createdAt": ms(created),
            "isArchived": False,
            "originCwd": self.cwd,
        }
        meta.update(extra or {})
        with open(os.path.join(self.meta_dir, f"{LOCAL}.json"), "w") as fh:
            json.dump(meta, fh)
        with open(self.transcript, "w") as fh:
            for e in entries:
                fh.write(json.dumps(e) + "\n")

    def seed_state(self, since, title="Opening question"):
        os.makedirs(self.state_dir, exist_ok=True)
        with open(os.path.join(self.state_dir, f"{LOCAL}.json"), "w") as fh:
            json.dump({"title": title, "since": ms(since)}, fh)

    def run_hook(self, stop_hook_active=False, now=None):
        env = dict(
            os.environ,
            CLAUDE_CODE_ENTRYPOINT="claude-desktop",
            CLAUDE_PROJECT_DIR=self.cwd,
            SESSION_TITLE_SYNC_META_ROOT=os.path.join(self.tmp.name, "meta"),
            SESSION_TITLE_SYNC_STATE_DIR=self.state_dir,
            SESSION_TITLE_SYNC_NOW_MS=str(ms(now or self.now)),
        )
        stdin = json.dumps(
            {
                "session_id": CLI,
                "transcript_path": self.transcript,
                "cwd": self.cwd,
                "stop_hook_active": stop_hook_active,
            }
        )
        out = subprocess.run(
            [sys.executable, "-I", HOOK],
            input=stdin,
            env=env,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        return json.loads(out) if out else None

    def multi_day(self):
        d1 = dt.datetime(2026, 11, 9, 10, 0)
        return d1, [user(d1), assistant(d1), user(self.now), assistant(self.now)]

    def test_title_unchanged_across_days_blocks_and_asks_for_compact(self):
        created, entries = self.multi_day()
        self.write(entries, created)
        out = self.run_hook()
        self.assertEqual(out["decision"], "block")
        self.assertIn("across 2 days", out["reason"])
        self.assertIn("/compact", out["reason"])

    def test_rerun_after_block_allows_stop(self):
        created, entries = self.multi_day()
        self.write(entries, created)
        self.assertIsNone(self.run_hook(stop_hook_active=True))

    def test_evening_session_across_utc_midnight_is_one_day(self):
        evening = dt.datetime(
            2026, 11, 11, 16, 30
        )  # UTC rolls over during these turns in the US
        late = dt.datetime(2026, 11, 11, 23, 30)
        self.write(
            [user(evening), assistant(evening), user(late), assistant(late)], evening
        )
        self.assertIsNone(self.run_hook(now=late))

    def test_late_night_past_midnight_is_not_days(self):
        late = dt.datetime(2026, 11, 10, 23, 0)
        after = dt.datetime(2026, 11, 11, 1, 0)
        self.write([user(late), assistant(late), user(after), assistant(after)], late)
        self.assertIsNone(self.run_hook(now=after))

    def test_turn_that_already_renamed_allows_stop(self):
        created, entries = self.multi_day()
        entries[-1] = assistant(
            self.now,
            tools=[
                ("mcp__ccd_session_mgmt__set_session_title", {"session_id": "self"})
            ],
        )
        self.write(entries, created, source="tool")
        self.assertIsNone(self.run_hook())

    def test_nudges_once_per_title_per_day(self):
        created, entries = self.multi_day()
        self.write(entries, created)
        self.assertIsNotNone(self.run_hook())
        entries += [user(self.now), assistant(self.now)]
        self.write(entries, created)
        self.assertIsNone(self.run_hook())

    def test_new_title_resets_the_clock(self):
        created, entries = self.multi_day()
        self.write(entries, created)
        self.run_hook()
        self.write(entries, created, source="user", title="Renamed by the user")
        self.assertIsNone(self.run_hook())

    def test_user_title_skips_long_but_not_days(self):
        start = dt.datetime(2026, 11, 11, 9, 0)
        entries = []
        for i in range(30):
            t = start + dt.timedelta(minutes=i)
            entries += [user(t), assistant(t)]
        self.write(entries, start, source="user", extra={"titleTurn": 1})
        self.seed_state(start)
        self.assertIsNone(self.run_hook())  # long, but the user chose the title

        created, entries = self.multi_day()
        self.seed_state(created)
        self.write(entries, created, source="user", extra={"titleTurn": 1})
        out = self.run_hook()
        self.assertIn("asks them to approve", out["reason"])

    def test_long_session_blocks(self):
        start = dt.datetime(2026, 11, 11, 9, 0)
        entries = []
        for i in range(25):
            t = start + dt.timedelta(minutes=i)
            entries += [user(t), assistant(t)]
        self.write(entries, start)
        self.assertIn("25 turns", self.run_hook()["reason"])

    def test_large_context_blocks(self):
        start = dt.datetime(2026, 11, 11, 9, 0)
        self.write([user(start), assistant(start, tokens=210_000)], start)
        self.assertIn("210K", self.run_hook()["reason"])

    def test_accepted_plan_blocks(self):
        start = dt.datetime(2026, 11, 11, 9, 0)
        self.write([user(start), assistant(start, tools=[("ExitPlanMode", {})])], start)
        self.assertIn("accepted a plan", self.run_hook()["reason"])

    def test_short_fresh_session_is_quiet(self):
        start = dt.datetime(2026, 11, 11, 17, 0)
        self.write([user(start), assistant(start)], start)
        self.assertIsNone(self.run_hook())

    def test_scheduled_session_is_skipped(self):
        created, entries = self.multi_day()
        self.write(entries, created, extra={"scheduledTaskId": "x"})
        self.assertIsNone(self.run_hook())

    def test_prompt_after_a_system_reminder_block_is_a_turn(self):
        d1 = dt.datetime(2026, 11, 9, 10, 0)
        prompt = [
            {
                "type": "text",
                "text": "<system-reminder>\nLinked sessions now\n</system-reminder>",
            },
            {"type": "text", "text": "Keep going on the ranges design"},
        ]
        entries = [
            user(d1),
            assistant(d1, tools=[("ExitPlanMode", {})]),
            user(self.now, prompt),
            assistant(self.now),
        ]
        self.write(entries, d1, source="tool")
        self.seed_state(d1)
        out = self.run_hook()
        self.assertIn("across 2 days", out["reason"])  # the second day counted
        self.assertNotIn(
            "accepted a plan", out["reason"]
        )  # the old plan is not this turn

    def test_app_events_do_not_count_as_user_days(self):
        d1 = dt.datetime(2026, 11, 9, 10, 0)
        entries = [
            user(d1),
            assistant(d1),
            user(self.now, "<side-sessions-event>done</side-sessions-event>"),
        ]
        self.write(entries, d1)
        self.assertIsNone(self.run_hook())


if __name__ == "__main__":
    unittest.main(verbosity=1)
