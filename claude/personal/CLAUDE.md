# Codex delegation

Before delegating work to Codex CLI, read `~/.claude-personal/skills/codex-cli/SKILL.md`. Use its observable background workflow unless the user explicitly selects another integration.

For an adversarial review of Claude's plan by Codex agents, use `~/.claude-personal/skills/adversarial-plan-review/SKILL.md` (`/adversarial-plan-review`). Keep plan review distinct from implementation/diff review.

For session-efficiency audits, read `~/.claude-personal/skills/session-retrospective/SKILL.md`. Keep audit tools and findings in this profile.

In shell commands, quote wildcard option values (for example `--include="*.swift"`) and handle empty file sets explicitly; an unmatched zsh glob can fail before the program runs.
