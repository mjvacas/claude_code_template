---
description: Onboard to the codebase at the start of a session — restore context, summarize current state, propose next step.
argument-hint: "[optional focus area]"
allowed-tools: Bash(git log:*), Bash(git status:*), Bash(git diff:*), Read, Glob
---

Restore working context and orient before any coding.

## Current state

- Recent commits: !`git log --oneline -10`
- Working tree: !`git status --short`

## Human-curated decision log

@AI_CONTEXT.md

## Your task

1. Read the most recent session block in `AI_CONTEXT.md` above (decisions, open questions, next steps). Native auto-memory has already surfaced learned patterns — don't re-derive them.
2. If a focus area was given ($ARGUMENTS), skim the relevant files/ADRs under `docs/adr/`.
3. Report back, briefly:
   - **Last completed** / **In progress** / **Next planned**
   - Any blockers or open questions from the log
   - The single next action you'd take, and ask the user to confirm or redirect.

Keep it tight. Do not start editing until the user confirms direction.

For the full onboarding procedure and rationale, see @templates/AI_SESSION_START.md.
