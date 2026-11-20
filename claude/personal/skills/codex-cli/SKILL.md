---
name: codex-cli
description: Delegate tasks from Claude to Codex CLI with live progress, tracked background workers, and reliable final output. Load before launching codex exec, including parallel reviewers.
---

# Observable Codex delegation

Claude owns coordination and synthesis. Run Codex directly for this workflow; explicitly requested plugin commands retain their own contract.

## Launch

- Give each worker a name, exact task, absolute working directory, and unique scratch directory. Store the prompt in `prompt.md`; state scope, constraints, evidence paths, and required final response. Tell the worker to return its result in its final message, not write a report or ask for an output path.
- Use `codex exec --json -o` to separate live events from the final response. Preserve configured model/effort unless requested otherwise. Use read-only for review; authorized implementation uses workspace-write and its own worktree. Disable Xcode MCP for workers that do not need it.
- Launch each worker through Claude's Bash tool with `run_in_background: true`. Save its task ID and label immediately. Use an explicit Bash script so zsh glob behavior and shell cwd resets cannot change the launch.

Review launch example: save this as `launch.sh` in the worker's scratch directory, then run `bash "$run/launch.sh" "$worktree" "$run"` in the background. Both arguments must be absolute paths, and `prompt.md` must already exist.

```bash
#!/bin/bash
set -u
worktree=$1
run=$2
codex exec --json -C "$worktree" -s read-only \
  -c 'mcp_servers.xcode.enabled=false' \
  -o "$run/final.md" - < "$run/prompt.md" \
  > "$run/events.jsonl" 2> "$run/stderr.log" &
worker_pid=$!
printf '%s\n' "$worker_pid" > "$run/pid"
wait "$worker_pid"
run_exit=$?
printf '%s\n' "$run_exit" > "$run/exit-code"
exit "$run_exit"
```

## Observe and finish

- Immediately surface each worker's task and log paths, plus a live monitor command the user can run in another terminal. For example, with `run` set to the actual scratch path:

  ```bash
  tail -n +1 -F "$run/events.jsonl" | jq --unbuffered -r \
    '[.type, (.item.type // ""), (.item.command // .item.text // .thread_id // "")] | @tsv'
  ```

- Read incremental events and stderr with brief checks; use background completion notifications. Never occupy a foreground Bash call with a minutes-long sleep/poll loop or count report files with globs. Capture the `thread.started` thread ID for later resumption.
  The harness primitives for waiting are Bash `run_in_background` with an `until` loop (one completion notification) and `Monitor` (an event stream); a foreground `for … sleep` loop burns the 10-minute cap and was measured at 51 capped calls in one session (`~/.claude-personal/tuneloop/retro-2026-09-10.md` §1).
- While waiting, give a compact update at least every 60 seconds: worker name, latest command/tool or message, elapsed time, and time since its last event. Label silence as quiet, not proof of a hang. Surface errors and questions promptly; never claim all workers are working based only on missing reports or live PIDs.
- Completion requires a successful task exit, a completed Codex turn, and a usable final response. An empty report, clarification question, error, or hook failure must be inspected; report existence alone is insufficient. Preserve all logs and report incomplete workers separately from successful reviews.
- Before retrying, establish whether the original task has exited. Fix the concrete cause; preserve the prior attempt and use a new scratch directory. Resume by explicit thread ID when appropriate, never `--last` across parallel workers. After one unsuccessful recovery, report the blocker instead of repeatedly relaunching.

This CLI workflow exposes progress; it does not provide interactive steering. Use an App Server integration only when that capability is requested.
