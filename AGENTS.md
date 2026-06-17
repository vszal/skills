# Skills development

## Use skills
- Use skill-creator to create and test skills
- Use token-efficiency skill to make compact edits (remove extra conversational text) for machine readability. Structure the skill for token efficiency using progressive disclosure.

## Eval-run tooling
- Local-MLX eval-generation scripts live in `~/Code/skill-evaluation-tools` (own repo + CLAUDE.md). Invoke via stable symlinks: `~/.local/bin/run-eval-iteration.sh` (full round) / `~/.local/bin/run-eval-local.sh` (single). Grading stays on Claude.

## Skill iteration process
Plan: first tell me what you plan to do and get approval before editing files
Compact: make concise edits for token efficiency.
Evaluate: run evaluation and compare against previous iteration. Use agents to isolate context.
Hold for approval: summarize changes, evaluation grade and ask to commit and push to git.
