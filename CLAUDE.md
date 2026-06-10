# CLAUDE.md Template
# Copy this to the root of your new project and customize.
# Delete this header block after copying.
# ---

# Project Name

> One-line description of what this project does.

## Tech Stack

- **Language**: [e.g., TypeScript, Python, Go]
- **Framework**: [e.g., Next.js, FastAPI, Rails — or "none"]
- **Database**: [e.g., PostgreSQL, SQLite — or "none"]
- **UI**: [e.g., React Native Paper, Tailwind — or "none" for CLIs/services]
- **AI**: [e.g., Claude API, OpenAI API — or "none"]

## Project Structure

```
src/                # or app/, lib/, cmd/ — follow your stack's idiom
├── <entrypoints>   # screens, routes, CLI commands, handlers
├── <domain>        # business logic, services
├── <shared>        # pure helpers, utilities
└── <types>         # data contracts / schemas / models
```

## Key Files

- `[path to core data types/schemas]` — Core data contracts
- `[path to database schema & queries — if any]`
- [Add other important files as they emerge]

## Commands

```bash
[dev command]       # e.g., npm start, uvicorn app:app, go run .
[test command]      # e.g., npm test, pytest, go test ./...
[check command]     # e.g., npx tsc --noEmit, ruff check, go vet
```

## Conventions

- Commit prefixes: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`
- **Don't duplicate — share.** When logic appears twice, extract it into one shared module and fold the existing copies in; never let a third copy appear. If the same computation runs in two contexts (prod vs. tests/simulation, or sibling features), share the *exact* implementation so they can't silently drift. Grep for the pattern before writing a near-duplicate.
- Keep entry points thin (screens, routes, CLI handlers) — push logic into services/modules
- Types first: define data contracts (types/schemas/models) before building features
- Defensive defaults at boundaries only: normalize external/untrusted data with safe fallbacks (JS `?? 0`, Python `.get(key, default)`); don't validate trusted internal calls
- After refactoring deterministic code, verify behavior is unchanged against a saved baseline output — stronger than "tests still pass"
- Treat `.claude/` skills/commands/agents/hooks and MCP servers as dependencies: vet before adding, review every update, keep unvetted ones out of version control — see docs/skill-security.md

## Hard Constraints (guarded by code)

Critical invariants are enforced **in code** — asserted at startup or at the
relevant boundary — not merely documented, so they can't silently regress. Config
that governs behavior lives in version-controlled files changed via PR review,
never a runtime toggle/UI. List this project's code-guarded invariants here, e.g.:

- **Catastrophic shell commands are hard-blocked** by the `PreToolUse` hook
  `.claude/hooks/block-dangerous.sh` (exit 2) — a safety net, not a sandbox. Ships with this template.
- `<INVARIANT>` — asserted at startup; the process refuses to run if violated.
- `<limit/threshold>` — enforced in `<module>`; violations are rejected, not warned.

## Architecture Decisions

- **[ADR-001](docs/adr/ADR-001-vendor-with-source-pin.md)** — adopters track vendored template files via a root `VENDORED.md` sidecar pinning upstream SHAs; per-file headers are optional.
- **[ADR-002](docs/adr/ADR-002-ai-context-archive-threshold.md)** *(superseded by [ADR-004](docs/adr/ADR-004-ai-context-archive-threshold-bump.md))* — original 500-line / 6k-token research-anchored derivation of the `AI_CONTEXT.md` archive threshold.
- **[ADR-003](docs/adr/ADR-003-cc-task-bench-scope.md)** — `cc-task-bench` V1 measures 3 deterministic task families (refactor, explore, test-write) across Opus 4.7/4.8, Sonnet 4.6, Haiku 4.5 with 5 runs/cell = **60 attempts per run**; methodology + fixture layout ship now, runner is V2.
- **[ADR-004](docs/adr/ADR-004-ai-context-archive-threshold-bump.md)** — `AI_CONTEXT.md` archive threshold raised to **750 lines** (~9k tokens) AND `/handoff` now requires each session block to be state-sufficient for cold pickup; the discipline makes archival safe at the higher cap.

<!-- Add decisions as they're made. Format: -->
<!-- - **Decision**: What was decided -->
<!-- - **Why**: Rationale -->
<!-- - **Alternatives considered**: What else was evaluated -->

## AI Integration Patterns (if applicable)

- Provider-agnostic interface for LLM calls (easy to swap Claude/OpenAI/etc.)
- Cache LLM responses to avoid inconsistent results across call sites
- Log AI inputs/outputs for debugging: `[LLM] Input:`, `[LLM] Response:`
- Validate and normalize all AI-generated data with defaults

## Context System

Hybrid memory — two stores, kept from overlapping:

- **CLAUDE.md** (this file): static project rules and conventions. Auto-loaded every session. Keep under 200 lines.
- **AI_CONTEXT.md**: *human-curated* decisions, rationale, open questions, next steps — what a future reader can't reconstruct from the diff. Auto-loaded via @AI_CONTEXT.md. Update at end of session with `/handoff`.
- **Native auto-memory** (`~/.claude/projects/<project>/memory/`, on by default): patterns and build quirks Claude *learns* on its own. Browse/edit with `/memory`. Don't copy these into AI_CONTEXT.md.
- **docs/adr/ADR-NNN-*.md**: Architecture Decision Records — one per significant or hard-to-reverse decision (Status / Context / Decision / Consequences / Alternatives Considered). Don't re-litigate a decided ADR; if it genuinely needs revisiting, write a new one that supersedes it. Keep a one-line highlight per ADR in the "Architecture Decisions" section above.
- **docs/summaries/YYYY-MM.md**: Monthly compressed recaps.
- **docs/{PROJECT_SPEC,ARCHITECTURE,BUILD_PLAN}.md** (optional; scale to project size): the source-of-truth triad — the "why/what", the "how", and the "in what order". Read at session start; don't re-litigate decisions captured here (revisit via a new ADR). Skeletons in `templates/`.
- **.claude/**: native Claude Code config — `settings.json` (permissions, statusline, SessionStart + PreToolUse + PreCompact hooks), `hooks/` (session-context, block-dangerous, precompact-snapshot), `commands/` (`/session-start`, `/handoff`, `/commit`, `/adr`), `skills/` (verify-refactor, tune-parameters, llm-eval, cc-task-bench). Code review is delegated to the `pr-review-toolkit@claude-plugins-official` baseline plugin installed during adoption (see docs/ADOPTING.md). See docs/claude-code-setup.md.
- **Rule**: Commit code + AI_CONTEXT.md updates together atomically.

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed. 
Tradeoff: These guidelines bias toward caution over speed. For trivial tasks, use judgment. 
1. Think Before Coding Don't assume. Don't hide confusion. Surface tradeoffs. Before implementing: State your assumptions explicitly. If uncertain, ask. If multiple interpretations exist, present them - don't pick silently. If a simpler approach exists, say so. Push back when warranted. If something is unclear, stop. Name what's confusing. Ask. 
2. Simplicity First Minimum code that solves the problem. Nothing speculative. No features beyond what was asked. No abstractions for single-use code. No "flexibility" or "configurability" that wasn't requested. No error handling for impossible scenarios. If you write 200 lines and it could be 50, rewrite it. Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify. 
3. Surgical Changes Touch only what you must. Clean up only your own mess. When editing existing code: Don't "improve" adjacent code, comments, or formatting. Don't refactor things that aren't broken. Match existing style, even if you'd do it differently. If you notice unrelated dead code, mention it - don't delete it. When your changes create orphans: Remove imports/variables/functions that YOUR changes made unused. Don't remove pre-existing dead code unless asked. The test: Every changed line should trace directly to the user's request. 
4. Goal-Driven Execution Define success criteria. Loop until verified. Transform tasks into verifiable goals: "Add validation" → "Write tests for invalid inputs, then make them pass" "Fix the bug" → "Write a test that reproduces it, then make it pass" "Refactor X" → "Ensure tests pass before and after" For multi-step tasks, state a brief plan: 
1. [Step] → verify: [check] 
2. [Step] → verify: [check] 
3. [Step] → verify: [check] Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification. 

These guidelines are working if: fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
