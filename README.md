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
.gitignore                    # Ignores Claude-local files, secrets/env, scan output
.claude/
├── settings.json             # Permissions (deny secret reads + exfil tools), SessionStart hook
├── settings.local.json.example
├── settings.lockdown.json.example  # Opt-in egress denies for vetting untrusted skills
├── hooks/session-context.sh  # Prints recent git activity at session start
├── commands/                 # /session-start, /handoff
├── agents/                   # code-reviewer subagent
└── skills/                   # verify-refactor, tune-parameters, llm-eval
scripts/
├── check-template.sh         # Integrity + secrets smoke-test (run manually)
└── audit-config.sh           # Reports what .claude/ artifacts do — vet skills before trusting
docs/
├── claude-code-setup.md      # How the native config is wired; what to customize
├── skill-security.md         # Trust model, vetting checklist, SAST options
└── adr/                      # Filled-in Architecture Decision Records go here
templates/                    # Reference docs + blank templates (loaded on demand)
├── ADR-template.md           # Copy into docs/adr/ when recording a decision
├── PROJECT_SPEC.md / ARCHITECTURE.md / BUILD_PLAN.md   # source-of-truth triad
├── AI_SESSION_START.md
└── LLM_APP_DEVELOPMENT_BEST_PRACTICES.md
old/                          # Historical, project-specific originals — don't copy
```

## Hybrid memory model

Two complementary stores, kept from overlapping:

- **`AI_CONTEXT.md`** (committed) — decisions a *human* made and why. Updated via `/handoff`.
- **Native auto-memory** (`~/.claude/...`, machine-local, on by default) — patterns Claude *learns* on its own. Browse with `/memory`.

If a human decided it, it goes in `AI_CONTEXT.md`. If Claude noticed it, let auto-memory hold it.

## Security

Skills, commands, hooks, and MCP servers are code you install. Before adding anything
from outside this repo, vet it — see `docs/skill-security.md`. Quick tools:

- `bash scripts/audit-config.sh <path>` — report what a skill/config actually does
  (dynamic execution, tool grants, egress/secret tokens) before you trust it.
- `bash scripts/check-template.sh` — validate config integrity + secrets hygiene.
- The default `settings.json` denies secret reads; `settings.lockdown.json.example`
  adds network-egress denies for quarantining untrusted skills.

## What's distinctive here

Beyond standard scaffolding, this template encodes a few hard-won engineering
practices as runnable skills and reviewer rules:

- **`/verify-refactor`** — prove a refactor preserved behavior by diffing deterministic output (byte-identical), not just "tests pass."
- **`/tune-parameters`** — pick a threshold by reading the *shape* of the metric surface, rejecting overfit spikes.
- **`/llm-eval`** — gate AI features on accuracy against a ground-truth set.
- **`code-reviewer`** subagent — reviews diffs for surgical scope, simplicity, and duplication.

See `docs/claude-code-setup.md` for the full tour.
