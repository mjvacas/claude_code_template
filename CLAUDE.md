# CLAUDE.md Template
# Copy this to the root of your new project and customize.
# Delete this header block after copying.
# ---

# Project Name

> One-line description of what this project does.

## Tech Stack

- **Framework**: [e.g., React Native + Expo, Next.js, FastAPI]
- **Language**: [e.g., TypeScript, Python]
- **Database**: [e.g., SQLite, PostgreSQL, Supabase]
- **UI**: [e.g., React Native Paper, Tailwind, shadcn/ui]
- **AI**: [e.g., Claude API, OpenAI API — or "none"]

## Project Structure

```
src/
├── screens/        # (or pages/, routes/) One file per screen/page
├── components/     # Reusable UI components
├── services/       # Business logic, API clients, database
├── utils/          # Pure helper functions
├── types/          # TypeScript type definitions
└── hooks/          # Custom React hooks
```

## Key Files

- `src/types/index.ts` — Core data types
- `src/services/database.ts` — Database schema and queries
- [Add other important files as they emerge]

## Commands

```bash
npm start           # Start dev server
npm test            # Run tests
npx tsc --noEmit    # Type check
```

## Conventions

- Commit prefixes: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`
- **Don't duplicate — share.** When logic appears twice, extract it into one shared module (`src/utils/`, `src/services/`) and fold the existing copies in; never let a third copy appear. If the same computation runs in two contexts (prod vs. tests/simulation, or sibling features), share the *exact* implementation so they can't silently drift. Grep for the pattern before writing a near-duplicate.
- Keep screens thin — push logic into hooks and services
- Types first: define data contracts in `types/` before building features
- Defensive defaults at boundaries only: normalize external/untrusted data (`?? 0` / `?? ''`); don't validate trusted internal calls
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

<!-- Add decisions as they're made. Format: -->
<!-- - **Decision**: What was decided -->
<!-- - **Why**: Rationale -->
<!-- - **Alternatives considered**: What else was evaluated -->

## AI Integration Patterns (if applicable)

- Provider-agnostic interface for LLM calls (easy to swap Claude/OpenAI/etc.)
- Cache LLM responses to avoid inconsistent results across screens
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
- **.claude/**: native Claude Code config — `settings.json` (permissions, statusline, SessionStart + PreToolUse + PreCompact hooks), `hooks/` (session-context, block-dangerous, precompact-snapshot), `commands/` (`/session-start`, `/handoff`, `/commit`, `/adr`), `skills/` (verify-refactor, tune-parameters, llm-eval). Code review is delegated to the `pr-review-toolkit@claude-plugins-official` baseline plugin installed during adoption (see docs/ADOPTING.md). See docs/claude-code-setup.md.
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
