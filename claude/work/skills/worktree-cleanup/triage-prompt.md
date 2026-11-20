You are triaging stale git refs in the repo at {REPO}. The owner deletes aggressively to cut cognitive load, but must NOT lose a novel idea or forget unmerged work that should ship. For each ref, judge what it holds against what already landed on origin/main.

STRICTLY READ-ONLY: no checkout, commit, branch delete, push, fetch, stash, worktree change or file edit in the repo. Only git read commands (log, diff, show, status, cherry, grep, merge-base) via `git -C`, and `gh pr list/view`. Write only your output file.

Refs, one per line, in {LIST}. `origin/x` is a remote-tracking ref; an absolute path is a worktree: triage its HEAD commits AND its uncommitted changes (`git -C <path> status --short`, `git -C <path> diff`, and read untracked files, handoff docs especially).

For each ref:
1. `git log --oneline origin/main..REF`, `git diff --stat origin/main...REF`; read the substantive diff (skip lockfiles, pbxproj).
2. Did the idea land? History is usually SQUASH-merged, so ancestry lies. Search origin/main for the key symbols, files and doc sections (`git grep`, `git log origin/main --grep`); per touched path, `git diff origin/main REF -- <path>` shows what is still not on main. Check PRs by head and by keyword. Check the repo's followups / product-direction docs for whether the idea is already recorded.
3. novelty 0–3: 0 landed, duplicate or trivial; 1 minor leftovers; 2 a real idea or work not on main; 3 significant unique work the owner would regret losing. impact 0–3 for the product.
4. needs_merge: finished-looking work that should ship rather than be dropped.
5. If another ref or a doc on main cites a commit only this ref reaches, say so in evidence: it needs a tag before deletion.

Write JSONL to {OUT}, one object per ref:
{"ref","what" (one plain sentence),"uncommitted" (short phrase or ""),"landed" ("full"|"partial"|"none"),"evidence" (the main commit/PR/file that proves it, or what is missing),"novelty","impact","needs_merge" (bool),"recommend" ("delete"|"capture-idea-then-delete"|"keep"),"idea_note" (for capture: 1–2 sentences for the followups doc, naming the commit SHA that holds the code; else ""),"tag" (SHA needing a tag, or "")}

Be skeptical both ways: unmerged ancestry is not novelty, and "landed" needs evidence. Final reply: count per recommendation, then each ref with novelty >= 2 on one line.
