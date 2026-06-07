---
description: End-of-session handoff — record decisions in AI_CONTEXT.md and commit code + context together atomically.
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(wc:*), Read, Edit
---

Close out the session so the next one can resume cleanly.

## What changed

- Working tree: !`git status --short`
- Staged + unstaged diff summary: !`git diff --stat HEAD`
- `AI_CONTEXT.md` size: !`wc -l < AI_CONTEXT.md | tr -d ' '` lines (archive oldest blocks to `docs/summaries/YYYY-MM.md` if > 500 — see @docs/adr/ADR-002-ai-context-archive-threshold.md)

## Your task

1. Append (or update) a dated session block in `AI_CONTEXT.md` — the **human-curated** half of the hybrid memory model. Capture only what a future reader can't reconstruct from the diff:
   - **Decisions** made and the *why* (and alternatives rejected)
   - **Open questions** / blockers
   - **Next steps**
   Promote any decision that is significant or hard to reverse into a new `docs/adr/ADR-NNN-*.md` (copy from @templates/ADR-template.md).
2. Leave learned patterns / build quirks to native auto-memory — don't duplicate them into `AI_CONTEXT.md`.
3. **If `AI_CONTEXT.md` is over 500 lines**, move the oldest session blocks into `docs/summaries/YYYY-MM.md` (current month) and keep only recent blocks in `AI_CONTEXT.md`. Compress aggressively — one paragraph per archived session is fine. (Threshold rationale: @docs/adr/ADR-002-ai-context-archive-threshold.md)
4. Commit **code + `AI_CONTEXT.md` together** (plus any new `docs/summaries/` file) in one atomic commit. Use a conventional prefix (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`) and a body explaining what and why.
5. Confirm the working tree is clean and report the commit hash.

For the full handoff checklist, see @templates/AI_SESSION_START.md.
