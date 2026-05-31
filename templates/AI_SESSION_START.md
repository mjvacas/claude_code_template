# Starting & Ending an AI Coding Session

> **Purpose:** the session workflow this template assumes — how to restore context at the
> start, keep it current while you work, and hand off cleanly at the end.
> The `/session-start` and `/handoff` commands automate most of this; read this when you
> want the full procedure and the *why* behind it.

---

## The memory model (where things live)

This template uses a hybrid memory. CLAUDE.md → **"Context System"** is the source of truth
for the full list; the short version:

- **`CLAUDE.md`** — static rules and conventions, auto-loaded every session.
- **`AI_CONTEXT.md`** — *human-curated* decisions, rationale, open questions, next steps.
  Auto-loaded via `@AI_CONTEXT.md`. Updated with `/handoff`.
- **Native auto-memory** (`~/.claude/projects/<project>/memory/`, machine-local, on by
  default) — patterns Claude *learns* on its own. Browse/edit with `/memory`. Don't
  hand-copy these into `AI_CONTEXT.md`.
- **`docs/adr/ADR-NNN-*.md`** — one record per significant or hard-to-reverse decision
  (scaffold with `/adr`).
- **`docs/summaries/YYYY-MM.md`** — monthly compressed recaps; old `AI_CONTEXT.md` blocks
  land here once the file gets long.

Rule of thumb: a *human* decided it → `AI_CONTEXT.md` (or an ADR). Claude *noticed* it →
let auto-memory hold it.

---

## Start of session — `/session-start [focus]`

The `SessionStart` hook (`.claude/hooks/session-context.sh`) already injects recent repo
activity. To actively orient:

1. Read the newest block in **`AI_CONTEXT.md`** — decisions, open questions, next steps.
2. Skim `git log --oneline -10` for what shipped recently.
3. If a focus area was given, skim the relevant files and `docs/adr/`.
4. Check the working tree (`git status`, `git diff`) for paused, in-progress work.
5. Report back briefly — **Last completed / In progress / Next planned**, plus any blockers
   — then confirm direction with the user **before editing**.

> **First session in a freshly cloned repo?** Vet what's in `.claude/` before it starts
> running on your machine — `bash scripts/audit-config.sh .claude/`, and see
> `docs/skill-security.md`. Hooks, slash commands, subagents, and MCP servers are code
> that runs on you.

`/session-start [focus]` runs steps 1–5 for you.

---

## During the session

- Update **`AI_CONTEXT.md`** as decisions happen — not "at the end" (a session can end
  abruptly).
- Commit **code + `AI_CONTEXT.md` together** in one atomic commit (`/commit`), with a
  conventional prefix (`feat:` / `fix:` / `refactor:` / `docs:` / `chore:`) and a body
  explaining *what* and *why*.
- Promote any significant or hard-to-reverse decision into an ADR (`/adr`).
- Leave learned patterns and build quirks to auto-memory — don't duplicate them in
  `AI_CONTEXT.md`.

**Red flags:** committing code without the matching `AI_CONTEXT.md` update; batching 5+
commits before recording context; planning to "document it later."

---

## End of session — `/handoff`

1. Append a dated block to **`AI_CONTEXT.md`**: Summary, Decisions (+ why / alternatives
   rejected), Open Questions, Next Steps. Capture only what a future reader *can't*
   reconstruct from the diff.
2. Promote decisions worth an ADR with `/adr` (copy from `templates/ADR-template.md`).
3. Commit code + `AI_CONTEXT.md` together (atomic), conventional prefix + explanatory body.
4. Confirm the working tree is clean and report the commit hash.

`/handoff` runs this checklist.

### Keeping `AI_CONTEXT.md` scannable

When it grows long, move the oldest session blocks into `docs/summaries/YYYY-MM.md` (one
compressed page per month) and keep only recent blocks in `AI_CONTEXT.md`.

---

## Recovering older context

- **`docs/summaries/YYYY-MM.md`** — month-by-month recaps.
- **`git log --oneline`** / **`git show <hash>`** — when and why a change landed.
- **`docs/adr/`** — the rationale for a standing decision. Don't re-litigate a decided ADR;
  if it genuinely needs revisiting, write a new one that supersedes it.
- **Legacy `docs/archive/*.gz`** — if you adopted this template before the hybrid-memory
  model, you may still have gzipped session archives there:
  `gunzip -c docs/archive/AI_CONTEXT_YYYY-MM.md.gz | less`. New work belongs in
  `docs/summaries/`.

---

## Quick reference

| Need | Use |
|------|-----|
| Orient at session start | `/session-start [focus]` |
| Record decisions + commit atomically | `/handoff` (or `/commit`) |
| Capture a hard-to-reverse decision | `/adr` |
| Browse what Claude learned on its own | `/memory` |

Key files: `CLAUDE.md` · `AI_CONTEXT.md` · `docs/adr/` · `docs/summaries/` · `templates/`.

---

**Reference guide.** In this template it lives in `templates/` and is loaded on demand —
the `/session-start` and `/handoff` commands link to it as `@templates/AI_SESSION_START.md`.
Copy it into your own project and adapt the command names and paths to match your setup.
*Example:* if you relocate this guide to `docs/`, also rewrite the two
`@templates/AI_SESSION_START.md` references in `.claude/commands/session-start.md` and
`handoff.md` to `@docs/AI_SESSION_START.md`. Portable across BSD/macOS and GNU sed:

```bash
sed -i.bak 's|@templates/AI_SESSION_START\.md|@docs/AI_SESSION_START.md|' \
  .claude/commands/session-start.md .claude/commands/handoff.md \
  && rm .claude/commands/session-start.md.bak .claude/commands/handoff.md.bak
```
