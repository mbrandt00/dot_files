---
name: revdiff-groups
description: Grouped revdiff review through a per-worktree queue the user opens with tmux prefix+v. Use instead of launching revdiff yourself whenever changes are reviewed in groups of related files - "review in groups", "grouped review", "split the review", "continue the review", "next review group", "address my revdiff notes on review group N", or resuming a paused grouped review. Claude writes the queue and addresses notes; only the user accepts a group.
---

# Grouped revdiff review

The user works across many tmux sessions and worktrees. A grouped review is
**pulled** by the user with tmux prefix+v, never pushed by Claude. Claude
prepares the groups; the user opens them when ready and gives each one a verdict.

## Rules

- **Never launch revdiff for a grouped review.** No launcher script, no
  `REVDIFF_TMUX_WINDOW`, no popup. Write the queue and tell the user to press prefix+v
  in this pane.
- **Never accept a group.** Only the user's verdict menu writes `accepted`.
  Quitting revdiff without notes is not approval, and nothing moves on by
  itself.
- **Never skip ahead.** Do not treat a group as reviewed unless `list` says
  `accepted`.
- Do not commit grouped work until every group is `accepted`, unless the user
  says otherwise.

## The tool: `revdiff-queue`

On PATH (`~/.local/bin`, source in `~/.config/tmux/`). Always pass `-C <worktree>`.

| Command | Use |
|---|---|
| `init [--force] [-- revdiff-args…]` | Start a queue. Omit args to let prefix+v detect them each time it opens (uncommitted → `--untracked`, else branch vs base, else last commit). Pass args such as `-- main` only when the review must use a fixed base. `--force` replaces an existing queue, so ask first. |
| `add --title T --description-file F -- file…` | Add one group and print its number. Paths are relative to the worktree root. |
| `list` | `N<TAB>status<TAB>title` |
| `show N` | Files, description, and the paths of the notes and draft |
| `reset N` | `changes` → `pending` after the notes are addressed |
| `clear` | Delete the queue once everything is accepted and the user agrees |

Statuses: `pending` (the user still has to review it), `changes` (notes are
waiting for Claude), `accepted` (only the user sets this).

## Starting a grouped review

1. Run `revdiff-queue -C <wt> list`. If a queue already exists, show its state
   and ask before you replace it.
2. Split the changes into 2–6 groups of related files. Order them so each group
   reads well after the ones before it. Put every changed file in exactly one
   group.
3. For each group, write a short description in the scratchpad (what changed,
   why, what to check), then run `add`.
4. Tell the user: "Queue ready: N groups. Press prefix+v in this pane." Then
   stop. Do not wait in a loop.

## When the user sends notes

The hand-off says: *Address my revdiff notes on review group N (…) in
<notes.md>…*

1. Read `notes.md`. It uses revdiff's annotation format: `## path:LINE (+/-)`
   followed by the comment.
2. Handle each note. Make the code change, or answer the question in chat.
3. Run `revdiff-queue -C <wt> reset N`.
4. Run `list` and report: "Group N is ready for re-review. prefix+v." If other
   groups have status `changes`, handle them too.

## "Continue the review" or resuming

Run `list`. Handle any `changes` groups as above. Then name the next `pending`
group and tell the user to press prefix+v. If everything is `accepted`, say so
and offer to commit and to run `clear`.

## What the user sees (for answering questions)

prefix+v opens a menu of groups (○ to review, ✎ waiting on Claude, ✓ accepted).
The cursor starts on the first group to review. revdiff floats over the pane.
After quitting, a verdict menu offers:
- **Accept** (only when there are no notes)
- **Send notes to Claude**
- **Reopen**
- **Later**

Esc counts as Later. Unsent notes stay as a draft and load again next time. `Q`
inside revdiff keeps the draft. Deleting every note and pressing `q` clears it.
With no queue, prefix+v reviews the whole diff as before.
