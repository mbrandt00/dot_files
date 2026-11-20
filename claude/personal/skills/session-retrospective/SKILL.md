---
name: session-retrospective
description: Analyze past claude-personal and delegated Codex sessions for repeated tool failures, redundant lookups, polling, and automation candidates using the local Tuneloop store. Use for session retrospectives and workflow-efficiency audits.
---

# Session retrospective

Keep this workflow, its configuration, and its findings under `~/.claude-personal`. The local Tuneloop installation is `~/.claude-personal/tuneloop`; invoke its `run` script. Read `trial-findings.md` there for the current sample and known measurement limitations.

1. Check actual log roots and sample coverage first. This user's personal Claude launcher uses `~/.claude-personal/projects`; do not silently substitute `~/.claude/projects`. Codex transcripts are read-only inputs from `~/.codex/sessions`. Record provenance and distinguish confirmed parent/child links from inferred associations.
2. Use bounded snapshots and the saved `static-config.json` with `--llm-provider ''` for an initial analysis. Do not enable LLM enrichment or transmit transcripts merely because an API key is available. Keep database, snapshots, reports, and any added adapters under the personal profile.
3. Run `~/.claude-personal/tuneloop/run query --schema` before querying. Aggregate tool calls and token usage separately before joining by session; distinguish wall time from summed parallel time. Check unknown model prices and missing source fields before interpreting totals.
4. Rank candidates by recurrence and avoidable effort: unchanged failed retries, repeated searches/reads without new evidence, reconstructed launch/report machinery, blocking polling, and hook failures. Tool count alone is not waste; user rejections, expected nonzero exits, independent reviews, and post-compaction rereads need context.
5. Verify each candidate against a small set of raw transcript events. Include session IDs and event/line references. Separate Tuneloop detector output from your own analysis. Its v0.7.0 parser missed nonzero Codex command results in this trial; zero reported errors is not proof of success.
6. Propose the smallest remedy: stable mechanics → tested script; judgment → skill; predictable lifecycle check → narrow hook calling shared code; discovery → short routing note. Keep raw findings in the report, not permanent instructions. Promote recurring, verified lessons only; don't auto-apply model-generated recommendations.
7. Validate an adopted change on comparable later sessions, preserving outcome quality. Report coverage gaps, unknowns, and unsuccessful workers explicitly. The requested personal SessionStart/Stop hooks are installed; read `~/.claude-personal/tuneloop/automation.md` for coverage, status files, and lifecycle limits. Do not add further recurring automation without a request.

The SessionStart hook ensures the dashboard is running on localhost:4319; use `run serve --no-open` for manual startup. It binds to localhost by default; the trial has no hosted enrichment and no GitHub outcome lookups.
