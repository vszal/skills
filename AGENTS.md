# Skills development

## Use skills
- Use skill-creator skill to create and test skills
- Use token-efficiency skills for compaction. *NEVER* remove valid guidance completely, just compact it for token efficiency. Target conversational filler, optimize for machine readability.

## Skill iteration process
Plan: first tell me what you plan to do and get approval before editing files
Compact: make concise edits for token efficiency.
Evaluate: run evaluation and compare against previous iteration. Use agents to isolate context.
Hold for approval: summarize changes, evaluation grade and ask to commit and push to git.

## Eval-run tooling
- If available, use Local-MLX eval-generation scripts which live in `~/Code/skill-evaluation-tools` (own repo + CLAUDE.md). Invoke via stable symlinks: `~/.local/bin/run-eval-iteration.sh` (full round) / `~/.local/bin/run-eval-local.sh` (single). Grading stays on cloud model.
- If local models are unavailable. use weaker cloud models like Haiku or Gemini Flash.

