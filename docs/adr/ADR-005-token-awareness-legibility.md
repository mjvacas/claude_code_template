# ADR-005: Token awareness ships as a legibility layer; measurement stays deferred

## Status

Accepted (2026-06-12) — to be superseded by `cc-task-bench` V2 measured routing
data (see [ADR-003](./ADR-003-cc-task-bench-scope.md)).

## Context

Higher-consumption models (Fable, the larger Opus tiers) made token cost a
first-class concern — for the maintainer running sessions and for adopters
weighing what the template costs them. The need surfaces at concrete decision
points: adopting a plugin, wiring a feature, choosing a model for a task.

Two distinct things get called "token awareness," and they cost very different
amounts to build:

- **Measurement** — get *real* per-task numbers by running a benchmark. This is
  `cc-task-bench` ([ADR-003](./ADR-003-cc-task-bench-scope.md)); V1 methodology
  ships, the runner is V2. It costs real dollars per run.
- **Legibility** — surface costs that are *already known or estimable* at the
  moment of decision. Ships now, ~zero recurring cost.

The legibility data already existed but was scattered and undiscoverable at the
decision point: [ADR-004](./ADR-004-ai-context-archive-threshold-bump.md) owns
the `AI_CONTEXT.md` token math, the plugin catalog carries per-model
`tokens.*.always_on` / `on_invoke`, and `CONTRIBUTING.md` states the
"recurring-cost features default to opt-in" principle — but nothing tied them
together, and there was **no** model-routing guidance at all. Gating any of this
on the out-of-scope, dollar-costing V2 runner would have blocked independently
valuable work.

## Decision

Ship the legibility layer now; keep measurement (`cc-task-bench` V2) in the
backlog. Three pieces, all in the new hub `docs/token-awareness.md` with thin
pointers from the docs that already touch cost:

1. **A cost-class taxonomy** — `free-local` / `on-use` / `session` /
   `per-prompt` — defined exactly once, mapped onto the catalog's two cost axes
   so the doc and plugin discovery speak one vocabulary. Other artifacts
   annotate against it (the `Cost` column in `docs/claude-code-setup.md`, the
   vetting line in `docs/skill-security.md`).
2. **A per-session cost ledger** that itemizes the always-on context tax but
   defers the *numbers* to the live native tools (`/context`, `/usage`) rather
   than freezing them in prose. The one anchored figure (a maxed `AI_CONTEXT.md`'s
   budget) stays owned by ADR-004 and is linked, not restated.
3. **A tier-based model-routing heuristic**, explicitly provisional, to be
   superseded by V2 measured data across its task families.

Guiding rule: **a stale cost number is worse than none.** Prefer durable cost
*classes* over frozen token/$ figures; point at live tools for the actuals.

## Consequences

- **The routing table ships without measured backing.** This is deliberate and
  labeled as a heuristic with an explicit supersession target — so a future
  session neither "fixes" it by inventing numbers nor deletes it as
  unsubstantiated.
- **The taxonomy becomes a cross-cutting convention.** Reversing or renaming the
  classes later means editing every annotated artifact — the hard-to-reverse
  signal that (per `CONTRIBUTING.md`) warrants this ADR.
- **Numbers stay live, not rotting in prose.** The cost the doc preaches is paid
  by native tools the user already has; the doc adds framing, not a second
  source of truth that drifts.
- **Apparent tension with ADR-003's measurement-first stance is accepted.** A
  heuristic is not a measured claim. Shipping one is justified because it is
  framed as provisional and carries a clean path to replacement by V2 data — the
  same supersede-when-measured shape ADR-002→004 already uses.
- The hub doc is referenced by a plain markdown link, **never** `@import`-ed into
  `CLAUDE.md` — importing the token-discipline doc would itself become a
  `session`-class context tax.

## Alternatives Considered

- **Numbers in prose** (frozen token/$ tables). Rejected: they rot the moment
  pricing or the template changes, and a wrong number reads as authoritative.
- **Measurement-first** (build `cc-task-bench` V2 before any docs). Rejected:
  blocks independently-valuable legibility on out-of-scope, dollar-costing work.
  The legibility layer is the framework V2's numbers later slot into, not a thing
  V2 replaces.
- **No routing guidance until measured.** Rejected: leaves the live "which model"
  question — sharpened by high-consumption models like Fable — unanswered. A
  labeled heuristic beats silence and has a clean supersession path.
- **A `cost:` frontmatter field on skills/commands.** Rejected: Claude Code
  doesn't read it, so it would look authoritative while being inert, and it would
  duplicate the human-facing `Cost` table. The annotation lives in the table only.
