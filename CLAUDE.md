# CLAUDE.md Template
# Copy this to the root of your new project and customize.
# Delete this header block after copying.
# ---

# Project Name

> What this project does, in one line.

## Tech Stack

- **Language**: [e.g., TypeScript, Python, Go]
- **Framework**: [e.g., Next.js, FastAPI, Rails, or "none"]
- **Database**: [e.g., PostgreSQL, SQLite, or "none"]
- **UI**: [e.g., React Native Paper, Tailwind, or "none" for CLIs and services]
- **AI**: [e.g., Claude API, OpenAI API, or "none"]

## Project Structure

```
src/                # or app/, lib/, cmd/ — follow your stack's idiom
├── <entrypoints>   # screens, routes, CLI commands, handlers
├── <domain>        # business logic, services
├── <shared>        # pure helpers, utilities
└── <types>         # data contracts / schemas / models
```

## Key Files

- `[path to core data types/schemas]`: core data contracts
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
- Before a nontrivial commit or PR, run your code review plugin's reviewer agent on the diff (baseline: `pr-review-toolkit`'s `code-reviewer`). Review agents are invoked by the model and never fire on their own
- Once a branch is pushed, don't amend or force push it. Add a fixup commit instead (the PreToolUse hook blocks force pushes outright)
- **Don't duplicate. Share.** When logic appears twice, extract it into one shared module and fold the existing copies in. Never let a third copy appear. If the same computation runs in two contexts (prod vs. tests or simulation, or sibling features), share the *exact* implementation so they can't silently drift. Grep for the pattern before writing a near duplicate.
- Keep entry points thin (screens, routes, CLI handlers). Push logic into services and modules
- Types first: define data contracts (types, schemas, models) before building features
- Defensive defaults at boundaries only: normalize external or untrusted data with safe fallbacks (JS `?? 0`, Python `.get(key, default)`). Don't validate trusted internal calls
- After refactoring deterministic code, verify behavior is unchanged against a saved baseline output. That's stronger than "tests still pass"
- **Personal info stays local.** Never send the user's email or other personal info (name, phone number, address) to an outside service without asking first. That includes request headers (a User-Agent counts), URLs, request bodies, MCP tool inputs, and code written to send it later. If an API wants contact info or a custom User-Agent, ask the user what to send. Even a project name can identify them. This applies to subagents too.
- Treat `.claude/` skills, commands, agents, hooks and MCP servers as dependencies: vet before adding, review every update, keep unvetted ones out of version control. See docs/skill-security.md

## Hard Constraints (guarded by code)

Critical invariants are enforced **in code**, asserted at startup or at the relevant
boundary, so they can't silently regress. Documenting them isn't enough. Config that
governs behavior lives in version controlled files changed through PR review, never in
a runtime toggle or UI. List this project's invariants guarded by code here, e.g.:

- **Catastrophic shell commands are blocked outright** by the `PreToolUse` hook
  `.claude/hooks/block-dangerous.sh` (exit 2). It's a safety net and doesn't sandbox anything. Ships with this template.
- `<INVARIANT>`: asserted at startup. The process refuses to run if it's violated.
- `<limit/threshold>`: enforced in `<module>`. Violations are rejected instead of warned about.

## Architecture Decisions

- **[ADR-001](docs/adr/ADR-001-vendor-with-source-pin.md)**: adopters track vendored template files with a root `VENDORED.md` sidecar that pins upstream SHAs. Headers in each file are optional.
- **[ADR-002](docs/adr/ADR-002-ai-context-archive-threshold.md)** *(superseded by [ADR-004](docs/adr/ADR-004-ai-context-archive-threshold-bump.md))*: the original derivation of the `AI_CONTEXT.md` archive threshold (500 lines, about 6k tokens), anchored in research.
- **[ADR-003](docs/adr/ADR-003-cc-task-bench-scope.md)**: `cc-task-bench` V1 measures 3 deterministic task families (refactor, explore, test-write) across Opus 4.7, Opus 4.8, Sonnet 4.6 and Haiku 4.5, with 5 runs per cell, so **60 attempts per run**. The method and fixture layout ship now. The runner is V2.
- **[ADR-004](docs/adr/ADR-004-ai-context-archive-threshold-bump.md)** *(superseded by [ADR-007](docs/adr/ADR-007-ai-context-archive-threshold-1000.md))*: raised the `AI_CONTEXT.md` archive threshold to 750 lines AND made `/handoff` require each session block to be state sufficient for a cold pickup. That discipline makes archival safe at the higher cap.
- **[ADR-005](docs/adr/ADR-005-token-awareness-legibility.md)**: token awareness ships now as a **legibility** layer (cost classes, the native `/context` and `/usage`, a cost ledger per session, and a model routing heuristic in `docs/token-awareness.md`). Empirical **measurement** stays deferred to `cc-task-bench` V2, which supersedes the routing heuristic.
- **[ADR-006](docs/adr/ADR-006-versioning-and-release-management.md)**: the template is now **versioned** (SemVer, starting at **v0.1.0, beta**), superseding the old "unversioned" `CHANGELOG` convention of dated entries. MAJOR, MINOR and PATCH are defined against the *adoption contract*. Adopters pin `VENDORED.md` to a **release tag** so re-sync can answer "am I behind and is it breaking?". v1.0.0 waits on validation from outside feedback.
- **[ADR-007](docs/adr/ADR-007-ai-context-archive-threshold-1000.md)**: raised the `AI_CONTEXT.md` archive threshold to **1000 lines**, from a replay of real archive history (about 30 to 50% fewer archives for ~2k more tokens per session). It keeps ADR-004's requirement that each block be state sufficient. The quality cost of a bigger file is still unmeasured.

<!-- Add decisions as they're made. Format: -->
<!-- - **Decision**: What was decided -->
<!-- - **Why**: Rationale -->
<!-- - **Alternatives considered**: What else was evaluated -->

## AI Integration Patterns (if applicable)

- A provider agnostic interface for LLM calls (easy to swap Claude, OpenAI and others)
- Cache LLM responses to avoid inconsistent results across call sites
- Log AI inputs and outputs for debugging: `[LLM] Input:`, `[LLM] Response:`
- Validate all data the AI generates and normalize it with defaults

## Context System

Hybrid memory. Two stores, kept from overlapping:

- **CLAUDE.md** (this file): static project rules and conventions. Loaded automatically every session. Keep under 200 lines.
- **AI_CONTEXT.md**: *human curated* decisions, rationale, open questions and next steps. What a future reader can't reconstruct from the diff. Loaded automatically through @AI_CONTEXT.md. Update at end of session with `/handoff`.
- **Native auto memory** (`~/.claude/projects/<project>/memory/`, on by default): patterns and build quirks Claude *learns* on its own. Browse and edit with `/memory`. Don't copy these into AI_CONTEXT.md.
- **docs/adr/ADR-NNN-*.md**: Architecture Decision Records, one per decision that's significant or hard to reverse (Status, Context, Decision, Consequences, Alternatives Considered). Don't relitigate a decided ADR. If it has to change, write a new one that supersedes it. Keep a one line highlight per ADR in the "Architecture Decisions" section above.
- **docs/summaries/YYYY-MM.md**: Monthly compressed recaps.
- **docs/{PROJECT_SPEC,ARCHITECTURE,BUILD_PLAN}.md** (optional, scale to project size): the three source of truth docs. They cover the "why and what", the "how", and the "in what order". Read them at session start. Don't relitigate decisions captured here (revisit them with a new ADR). Skeletons in `templates/`.
- **.claude/**: native Claude Code config. `settings.json` (permissions, statusline, SessionStart and PreToolUse hooks), `hooks/` (session-context, block-dangerous, and clock, which is opt-in), `commands/` (`/session-start`, `/handoff`, `/commit`, `/adr`), `skills/` (verify-refactor, tune-parameters, llm-eval, cc-task-bench). Code review is delegated to the `pr-review-toolkit@claude-plugins-official` baseline plugin installed during adoption (see docs/ADOPTING.md). See docs/claude-code-setup.md.
- **docs/token-awareness.md**: token cost of the context system. Cost classes (`free-local`, `on-use`, `session`, `per-prompt`), the context tax per session, compaction (including idle compaction), and a model routing heuristic. Loaded on demand only.
- **Rule**: Commit code and AI_CONTEXT.md updates together, atomically.

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
