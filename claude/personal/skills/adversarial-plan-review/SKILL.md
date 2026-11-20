---
name: adversarial-plan-review
description: Challenge Claude's proposed plan with independent Codex CLI agents before implementation. Use for adversarial plan review, stress-testing a plan, or asking Codex reviewers to challenge Claude's approach; not an implementation-only diff review.
---

# Adversarial plan review

Review the current Claude plan or the plan the user identifies. If none is available, ask for it. The deliverable is a verdict and proposed plan revisions, not implementation.

1. Freeze the exact plan into a scratch file with its goal, constraints, non-goals, relevant repository rules, and evidence paths. Give every reviewer the same version. Include repository location and revision/working-tree state; distinguish proposed behavior from code that already exists.
2. Read `~/.claude-personal/skills/codex-cli/SKILL.md` and launch two independent, read-only Codex workers by default (respect an explicitly requested count/model). Give each the packet and the prompt below, without Claude's preferred verdict or other reviewers' findings. Each worker reviews directly without delegating. Use the shared skill's live monitoring and completion checks.
3. Verify findings against the plan and evidence. Deduplicate, identify disagreements, and judge each finding on its evidence; agreement between runs is not proof. Record accepted findings and dismissals with reasons. Mark missing/failed reviewers as incomplete rather than implying consensus.
4. Return **READY**, **REVISE**, or **INCOMPLETE**, a one-line result per reviewer with report paths, the material findings, and the smallest proposed plan changes. Do not silently rewrite the plan or begin implementation. Re-review a revised plan only when requested or needed to resolve an accepted blocker; do not loop until reviewers agree.

Reviewer prompt (append the shared plan packet):

> Adversarially review this proposed plan against its goal and repository evidence. Try to find a concrete reason it will fail: unsupported assumptions, missed requirements, excess scope or simpler alternatives, ownership conflicts, unsafe sequencing, data/security risks, and acceptance checks that would pass despite a broken outcome. Trace the relevant code read-only. Distinguish verified defects from hypotheses and missing evidence; do not invent findings to meet a quota. For each material finding, give the plan step, evidence path/line where available, failure scenario, and smallest revision or experiment that resolves it. Return READY or REVISE, findings ordered by consequence, and remaining uncertainties in your final message. Do not edit files, execute implementation steps, delegate, or write a report file; the launcher saves your response.
