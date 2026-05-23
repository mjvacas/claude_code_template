---
description: End-of-session handoff — record decisions in AI_CONTEXT.md and commit code + context together atomically.
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Read, Edit
---

Close out the session so the next one can resume cleanly.

## What changed

- Working tree: !`git status --short`
- Staged + unstaged diff summary: !`git diff --stat HEAD`

## Your task

1. Append (or update) a dated session block in `AI_CONTEXT.md` — the **human-curated** half of the hybrid memory model. Capture only what a future reader can't reconstruct from the diff:
   - **Decisions** made and the *why* (and alternatives rejected)
   - **Open questions** / blockers
   - **Next steps**
   Promote any decision that is significant or hard to reverse into a new `docs/adr/ADR-NNN-*.md` (copy from @templates/ADR-template.md).
2. Leave learned patterns / build quirks to native auto-memory — don't duplicate them into `AI_CONTEXT.md`.
3. Commit **code + `AI_CONTEXT.md` together** in one atomic commit. Use a conventional prefix (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`) and a body explaining what and why.
4. Confirm the working tree is clean and report the commit hash.

For the full handoff checklist, see @templates/AI_SESSION_START.md.
