---
name: handoff
description: Write a restart-ready handoff doc for the current session and queue its tmux pane for a fresh relaunch after the usage window resets. Use when the usage Stop hook asks for one, when the user says "handoff", "write a handoff", "we're about to run out", or before a /clear on heavy in-progress work.
---

# Handoff

A fresh session that reads this doc must be able to resume without the old transcript. Write for that reader: it knows the repo and CLAUDE.md, nothing about this conversation.

## 1. Gather state (read-only, one pass)

- `git status --short`, `git branch --show-current`, `git log --oneline origin/main..HEAD`, and whether the branch is pushed (`git status -sb`).
- Background work this session started: running subagents, background shells, queued xq/pueue jobs (`pueue status --group xcode`), remote builds. For each, note what it was doing and **how the next session can tell whether it finished**: the commit it would make, the files it touches, the branch, the job id and where its log lands.
- Open PRs for the branch (`gh pr view --json number,state,url` if one exists).

Do not wait for background agents or jobs to finish before writing. Write now; they may be killed at the relaunch.

## 2. Write the doc

Path: `HANDOFF-<topic>.md` at the worktree root, untracked; never commit it. If a handoff for this work already exists (in the worktree root or `docs/`), update it in place instead of making a second one.

Sections, in this order, terse:

1. **Resume here**: one paragraph. The goal, where things stand, and the very next action.
2. **Branch and commits**: branch, commits since main with one line each, pushed or not, PR number.
3. **Uncommitted changes**: what each changed file is for, and whether it is finished, half-done, or a throwaway probe to revert.
4. **In flight when this was written**: each background agent or job, and the check that tells whether it committed, left changes, or never ran.
5. **Decisions**: what the owner approved, and options they rejected, so they are not proposed again.
6. **Next steps**: numbered, each one concrete enough to start on.
7. **Owed to the owner**: device checks, approvals, merges, anything gated on them.

## 3. Point memory at it

If a project memory entry covers this work, update its line in `MEMORY.md` and its file to name the handoff path. Otherwise add one.

## 4. Register for relaunch

```bash
~/.claude-personal/relaunch/register.sh <handoff-path> ["custom resume prompt"]
```

This records the tmux pane and worktree in `~/.claude-personal/relaunch/queue/` and starts the relaunch timer if one isn't running. At the usage reset plus 2 minutes, the timer stops each queued pane's Claude and starts a fresh one in the worktree with "Read <handoff> and resume." Exit code 2 means the session isn't in tmux. The handoff still stands, but say that the session must be restarted by hand.

Skip registration when the user only asked for a handoff doc, or said not to relaunch.

## 5. Report

One short message: the handoff path, what's in flight, and the exact resume prompt. Then stop.
