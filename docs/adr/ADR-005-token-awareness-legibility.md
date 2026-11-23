# ADR-005: Token awareness ships as a legibility layer, with measurement deferred

## Status

Accepted (2026-06-12). To be superseded by measured routing data from
`cc-task-bench` V2 (see [ADR-003](./ADR-003-cc-task-bench-scope.md)).

## Context

Higher consumption models (Fable, the larger Opus tiers) made token cost a
first class concern, both for the maintainer running sessions and for adopters
weighing what the template costs them. The need surfaces at concrete decision
points: adopting a plugin, wiring a feature, choosing a model for a task.

Two distinct things get called "token awareness." They cost very different
amounts to build:

- **Measurement.** Get *real* numbers per task by running a benchmark. This is
  `cc-task-bench` ([ADR-003](./ADR-003-cc-task-bench-scope.md)). V1 methodology
  ships, the runner is V2. It costs real dollars per run.
- **Legibility.** Surface costs that are *already known or estimable* at the
  moment of decision. Ships now, ~zero recurring cost.

The legibility data already existed but was scattered and undiscoverable at the
decision point. [ADR-004](./ADR-004-ai-context-archive-threshold-bump.md) owns
the `AI_CONTEXT.md` token math, the plugin catalog carries per model
`tokens.*.always_on` / `on_invoke`, and `CONTRIBUTING.md` states the
"recurring-cost features default to opt-in" principle. But nothing tied them
together. There was also **no** model routing guidance at all. Gating any of
this on the V2 runner, which is out of scope and costs dollars to run, would
have blocked work that was valuable on its own.

## Decision

Ship the legibility layer now. Keep measurement (`cc-task-bench` V2) in the
backlog. Three pieces, all in the new hub `docs/token-awareness.md` with thin
pointers from the docs that already touch cost:

1. **A cost class taxonomy** (`free-local` / `on-use` / `session` /
   `per-prompt`), defined exactly once and mapped onto the catalog's two cost
   axes so the doc and plugin discovery speak one vocabulary. Other artifacts
   annotate against it (the `Cost` column in `docs/claude-code-setup.md`, the
   vetting line in `docs/skill-security.md`).
2. **A per session cost ledger** that itemizes the always on context tax but
   defers the *numbers* to the live native tools (`/context`, `/usage`) rather
   than freezing them in prose. The one anchored figure (a maxed `AI_CONTEXT.md`'s
   budget) stays owned by ADR-004 and is linked instead of restated.
3. **A model routing heuristic based on tiers**, explicitly provisional, to be
   superseded by V2 measured data across its task families.

Guiding rule: **a stale cost number is worse than none.** Prefer durable cost
*classes* over frozen token or dollar figures. Point at live tools for the
actuals.

## Consequences

- **The routing table ships without measured backing.** This is deliberate. The
  table is labeled as a heuristic with an explicit supersession target, so a
  future session neither "fixes" it by inventing numbers nor deletes it as
  unsubstantiated.
- **The taxonomy becomes a cross cutting convention.** Reversing or renaming the
  classes later means editing every annotated artifact. Being hard to reverse is
  the signal that (per `CONTRIBUTING.md`) warrants this ADR.
- **Numbers stay live and don't rot in prose.** The cost the doc preaches is
  paid by native tools the user already has. The doc adds framing. It doesn't
  add a second source of truth that drifts.
- **Apparent tension with ADR-003's stance of measuring first is accepted.** A
  heuristic is not a measured claim. Shipping one is justified because it is
  framed as provisional and carries a clean path to replacement by V2 data. It's
  the same "supersede when measured" shape ADR-002→004 already uses.
- The hub doc is referenced by a plain markdown link and is **never** pulled
  into `CLAUDE.md` with `@import`. Importing the token discipline doc would
  itself become a `session` class context tax.

## Alternatives Considered

- **Numbers in prose** (frozen token and dollar tables). Rejected: they rot the
  moment pricing or the template changes. A wrong number reads as authoritative.
- **Measurement first** (build `cc-task-bench` V2 before any docs). Rejected:
  it blocks legibility, which is valuable on its own, on work that's out of
  scope and costs dollars. The legibility layer is the framework V2's numbers
  later slot into. V2 doesn't replace it.
- **No routing guidance until measured.** Rejected: leaves the live "which model"
  question (sharpened by high consumption models like Fable) unanswered. A
  labeled heuristic beats silence and has a clean supersession path.
- **A `cost:` frontmatter field on skills and commands.** Rejected: Claude Code
  doesn't read it, so it would look authoritative while being inert. It would
  also duplicate the `Cost` table meant for humans. The annotation lives in the
  table only.
