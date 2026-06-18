# Skills development

## Use skill-creator framework
- Use skill-creator skill to create and test skills

## Skill iteration process
- Plan: first tell me what you plan to do and get approval before editing files.
- Use token-efficiency skill for compaction. *NEVER* remove valid guidance completely. Target conversational filler, optimize for machine readability.
- Evaluate: run evaluation and compare against previous iteration. Use agents to isolate context.
- Hold for approval: summarize changes, evaluation grade and ask to commit and push to git.

## Eval-run tooling
- Use the skill-creator skill eval framework
- If available, offload evaluation to locally running models using scripts which live in `~/Code/skill-evaluation-tools` (own repo + CLAUDE.md). Invoke via stable symlinks: `~/.local/bin/run-eval-iteration.sh` (full round) / `~/.local/bin/run-eval-local.sh` (single). Grading stays on cloud model.
- If `~/Code/skill-evaluation-tools` is not present, use weaker cloud models like Haiku or Gemini Flash for evaluation, grading stays with more advanced cloud model.

