# Starting and Ending an AI Coding Session

> **Purpose:** the session workflow this template assumes. It covers how to restore
> context at the start, keep it current while you work, and hand off cleanly at the end.
> The `/session-start` and `/handoff` commands automate most of this. Read this when you
> want the full procedure and the *why* behind it.

---

## The memory model (where things live)

This template uses a hybrid memory. CLAUDE.md → **"Context System"** is the source of truth
for the full list. The short version:

- **`CLAUDE.md`**: static rules and conventions, loaded automatically every session.
- **`AI_CONTEXT.md`**: *human curated* decisions, rationale, open questions, next steps.
  Loaded automatically via `@AI_CONTEXT.md`. Updated with `/handoff`.
- **Native auto memory** (`~/.claude/projects/<project>/memory/`, local to your machine,
  on by default): patterns Claude *learns* on its own. Browse and edit with `/memory`.
  Don't copy these into `AI_CONTEXT.md` by hand.
- **`docs/adr/ADR-NNN-*.md`**: one record per significant or hard to reverse decision
  (scaffold with `/adr`).
- **`docs/summaries/YYYY-MM.md`**: monthly compressed recaps. Old `AI_CONTEXT.md` blocks
  land here once the file gets long.

Rule of thumb: a *human* decided it → `AI_CONTEXT.md` (or an ADR). Claude *noticed* it →
let auto memory hold it.

---

## Start of session: `/session-start [focus]`

The `SessionStart` hook (`.claude/hooks/session-context.sh`) already injects recent repo
activity. To actively orient:

1. Read the newest block in **`AI_CONTEXT.md`**: current state, decisions, open
   questions, next steps.
2. Skim `git log --oneline -10` for what shipped recently.
3. If a focus area was given, skim the relevant files and `docs/adr/`.
4. Check the working tree (`git status`, `git diff`) for paused work still in progress.
5. Report back briefly (**Last completed / In progress / Next planned**, plus any
   blockers), then confirm direction with the user **before editing**.

> **First session in a freshly cloned repo?** Vet what's in `.claude/` before it starts
> running on your machine. Run `bash scripts/audit-config.sh .claude/` and see
> `docs/skill-security.md`. Hooks, slash commands, subagents, and MCP servers are code
> that runs on your machine.

`/session-start [focus]` runs steps 1 to 5 for you.

---

## During the session

- Update **`AI_CONTEXT.md`** as decisions happen, not "at the end" (a session can end
  abruptly).
- Commit **code and `AI_CONTEXT.md` together** in one atomic commit (`/commit`), with a
  conventional prefix (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`) and a body
  explaining *what* and *why*.
- Promote any significant or hard to reverse decision into an ADR (`/adr`).
- Leave learned patterns and build quirks to auto memory. Don't duplicate them in
  `AI_CONTEXT.md`.

**Red flags:** committing code without the matching `AI_CONTEXT.md` update, batching 5+
commits before recording context, and planning to "document it later."

---

## End of session: `/handoff`

1. Append a dated block to **`AI_CONTEXT.md`**: Summary, Current state (where the work
   stands, so this block alone is enough to resume), Decisions (with why and the
   alternatives rejected), Open Questions, Next Steps. Capture only what a future
   reader *can't* reconstruct from the diff.
2. Promote decisions worth an ADR with `/adr` (copy from `templates/ADR-template.md`).
3. Commit code and `AI_CONTEXT.md` together (atomic), with a conventional prefix and an
   explanatory body.
4. Confirm the working tree is clean and report the commit hash.

`/handoff` runs this checklist.

### Keeping `AI_CONTEXT.md` scannable

When the file exceeds ~1000 lines, move the oldest session blocks into
`docs/summaries/YYYY-MM.md` (one compressed page per month) and keep only recent
blocks in `AI_CONTEXT.md`. Enforcement has two layers. The SessionStart hook nags at
every session start above the threshold. `/handoff` archives before committing.
Archival is safe because each handoff must produce a state sufficient latest block.
That block alone is enough for a cold `/session-start` to resume. Threshold rationale:
`docs/adr/ADR-007-ai-context-archive-threshold-1000.md` (supersedes ADR-004, the
750 line cap, which superseded ADR-002's original 500).

---

## Recovering older context

- **`docs/summaries/YYYY-MM.md`**: monthly recaps.
- **`git log --oneline`** and **`git show <hash>`**: when and why a change landed.
- **`docs/adr/`**: the rationale for a standing decision. Don't relitigate a decided ADR.
  If it has to change, write a new one that supersedes it.

---

## Quick reference

| Need | Use |
|------|-----|
| Orient at session start | `/session-start [focus]` |
| Record decisions and commit atomically | `/handoff` (or `/commit`) |
| Capture a hard to reverse decision | `/adr` |
| Browse what Claude learned on its own | `/memory` |

Key files: `CLAUDE.md` · `AI_CONTEXT.md` · `docs/adr/` · `docs/summaries/` · `templates/`.

---

**Reference guide.** In this template it lives in `templates/` and is loaded on demand.
The `/session-start` and `/handoff` commands link to it as `@templates/AI_SESSION_START.md`.
Copy it into your own project and adapt the command names and paths to match your setup.
*Example:* if you relocate this guide, prefer a namespaced subdir like
`docs/claude-code-template/` over a flat `docs/`. A flat `docs/` collides with
the `docs/{PROJECT_SPEC,ARCHITECTURE,BUILD_PLAN}.md` triad that CLAUDE.md reserves.
Then rewrite the two `@templates/AI_SESSION_START.md` references in
`.claude/commands/session-start.md` and `handoff.md` to
`@docs/claude-code-template/AI_SESSION_START.md`. Portable across BSD sed (macOS) and GNU sed:

```bash
sed -i.bak 's|@templates/AI_SESSION_START\.md|@docs/claude-code-template/AI_SESSION_START.md|' \
  .claude/commands/session-start.md .claude/commands/handoff.md \
  && rm .claude/commands/session-start.md.bak .claude/commands/handoff.md.bak
```
