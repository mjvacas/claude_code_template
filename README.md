# Claude Code Project Template

A starter scaffold for new projects that work well with **Claude Code** (May 2026).
It pairs Claude Code's native features (`.claude/` config, commands, subagents,
skills, hooks) with a small set of engineering-discipline practices.

## Quick start

1. Copy everything **except `old/`** into your new project's root.
2. Customize `CLAUDE.md` — fill in tech stack, structure, key files, commands. Keep it under 200 lines.
3. Tune `.claude/settings.json` — add your build/test/lint commands to the `allow` list.
4. Copy `.claude/settings.local.json.example` → `.claude/settings.local.json` for personal overrides (gitignored).
5. Delete any commands / agents / skills you don't want.
6. Read `docs/claude-code-setup.md` for the details.

## Layout

```
CLAUDE.md                     # Project rules + conventions (auto-loaded every session)
AI_CONTEXT.md                 # Human-curated decision log (auto-loaded via @import)
.gitignore                    # Ignores personal/local Claude files
.claude/
├── settings.json             # Permissions (deny secrets), defaultMode, SessionStart hook
├── settings.local.json.example
├── hooks/session-context.sh  # Prints recent git activity at session start
├── commands/                 # /session-start, /handoff
├── agents/                   # code-reviewer subagent
└── skills/                   # verify-refactor, tune-parameters, llm-eval
docs/
├── claude-code-setup.md      # How the native config is wired; what to customize
└── adr/                      # Filled-in Architecture Decision Records go here
templates/                    # Reference docs + blank templates (loaded on demand)
├── ADR-template.md           # Copy into docs/adr/ when recording a decision
├── AI_SESSION_START.md
└── LLM_APP_DEVELOPMENT_BEST_PRACTICES.md
old/                          # Historical, project-specific originals — don't copy
```

## Hybrid memory model

Two complementary stores, kept from overlapping:

- **`AI_CONTEXT.md`** (committed) — decisions a *human* made and why. Updated via `/handoff`.
- **Native auto-memory** (`~/.claude/...`, machine-local, on by default) — patterns Claude *learns* on its own. Browse with `/memory`.

If a human decided it, it goes in `AI_CONTEXT.md`. If Claude noticed it, let auto-memory hold it.

## What's distinctive here

Beyond standard scaffolding, this template encodes a few hard-won engineering
practices as runnable skills and reviewer rules:

- **`/verify-refactor`** — prove a refactor preserved behavior by diffing deterministic output (byte-identical), not just "tests pass."
- **`/tune-parameters`** — pick a threshold by reading the *shape* of the metric surface, rejecting overfit spikes.
- **`/llm-eval`** — gate AI features on accuracy against a ground-truth set.
- **`code-reviewer`** subagent — reviews diffs for surgical scope, simplicity, and duplication.

See `docs/claude-code-setup.md` for the full tour.
