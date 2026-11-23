# ADR-004: AI_CONTEXT.md archive threshold of 750 lines and a `/handoff` state sufficiency requirement

## Status

Superseded by [ADR-007](./ADR-007-ai-context-archive-threshold-1000.md) (2026-11-18).

Original status: Accepted (2026-06-09). Supersedes [ADR-002](./ADR-002-ai-context-archive-threshold.md). ADR-007 raises the cap to 1000 lines after measuring real files and archive frequency. It keeps this ADR's `/handoff` state sufficiency requirement.

## Context

[ADR-002](./ADR-002-ai-context-archive-threshold.md) set the threshold at **500 lines**, derived from the Lost in the Middle research (>30% retrieval degradation past ~10k tokens of total context) and an estimate of 12 tokens per line for decision log prose. The math is 500 × 12 = 6k tokens for `AI_CONTEXT.md`, leaving ~4k tokens for everything else (CLAUDE.md, recalled auto memories, the diff, the active conversation) inside the 10k attention safe envelope.

The math is still correct. The choice is being revisited because **the 500 line cap is hit often enough in practice that archival friction (SessionStart nag, `/handoff` interrupting the flow, more compression work per session) outweighs the retrieval cost it was guarding against. Sometimes the cap is hit after a single long session.**

A naive bump to 1000 was considered and rejected. It would sacrifice ADR-002's full retrieval cost headroom for friction relief, when a smaller bump can capture most of the friction relief without paying the full retrieval price.

### The deeper insight

The right knob to relax is more than "the cap". It's the implicit contract that older blocks need to stay loaded. A session block can be archived at any time without losing operational continuity **as long as the latest block is self-sufficient for cold pickup.** The friction at 500 came from being forced to archive in the middle of a session when the latest block hadn't yet captured everything the next session would need. It wasn't about losing information.

This decouples two things ADR-002 conflated:

- **How much do we want loaded automatically each session?** A token budget question, answered by the line cap.
- **What guarantees that archival doesn't lose continuity?** A handoff discipline question, answered by the state sufficiency requirement.

## Decision

Two coupled changes:

1. **Threshold: 750 lines** (~9k tokens at the estimate of 12 tokens per line). Tight headroom above ADR-002's 6k, still inside the 10k attention safe envelope when CLAUDE.md and recalled auto memory are kept lean.

2. **`/handoff` state sufficiency requirement.** Each handoff produces a session block whose **Current State, Decisions, Open Questions, and Next Steps** are sufficient for a cold `/session-start` to resume *without reading archived summaries*. The `/handoff` command checklist names this requirement explicitly. Archival is safe under this contract because the latest block alone carries operational continuity.

Enforcement still has two layers (SessionStart hook nag and `/handoff` archive step). The number is a single source of truth. Changing it requires updating the hook, the `/handoff` command, the `AI_CONTEXT.md` header, `templates/AI_SESSION_START.md`, the CLAUDE.md ADR highlight, and superseding this ADR.

## Consequences

- **Per session token tax for a maxed `AI_CONTEXT.md` rises ~50%.** ~6k → ~9k tokens. Combined context that loads automatically stays inside the 10k attention safe envelope under normal conditions. Long sessions on models with smaller context windows may occasionally cross it.
- **Archival friction drops.** Fewer SessionStart nags, less `/handoff` archival in the middle of work. One long productive session no longer routinely blows past the cap.
- **Handoff discipline tightens.** State sufficiency is the load bearing assumption that makes 750 and archival safe. It isn't a soft suggestion. A handoff that ships a vague "Next Steps" block silently violates the assumption and degrades the quality of a cold start.
- The estimate of 12 tokens per line is still load bearing. A project whose decision log prose runs denser (heavy code blocks, JSON, tables) will hit the token ceiling at fewer lines than this. If that's observed, supersede with a threshold based on tokens.
- If 750 turns out to be the wrong number in practice, supersede again, ideally with empirical data from a future measurement harness rather than another estimate.

## Alternatives Considered

- **Keep 500 lines (ADR-002).** Rejected: in practice the cap is hit often enough that archival friction outweighs the retrieval cost. ADR-002's math is still correct. This ADR explicitly accepts the trade documented there, but only partway. Choosing 750 rather than 1000 keeps most of the retrieval headroom intact.
- **Bump to 1000 lines.** Considered. Would relieve friction more completely but sacrifices ADR-002's full retrieval cost headroom. `AI_CONTEXT.md` alone would land at ~12k tokens, past the Lost in the Middle inflection before any other context is added. The state sufficiency requirement makes the additional headroom unnecessary, because archival is already safe.
- **Smaller session blocks and faster archival cadence** (hygiene per block instead of a ceiling per file). Considered. Same goal (reduce friction) via shorter blocks and monthly archival regardless of file size. Subsumed by the state sufficiency requirement, which already encourages tight latest blocks and makes aggressive archival safe.
- **Selective loading via `/session-start`** (skip automatic loading of `AI_CONTEXT.md` entirely and read only relevant blocks on demand). Considered. Bigger token win, but selective loading risks missing important details from older blocks the heuristic doesn't surface. Loading the (modestly larger) capped file automatically, plus a self-sufficient latest block, gives better worst case correctness at personal template scale.
- **Converting to a denser format aimed at machines** (JSON, terse shorthand, "byte code"). Considered. Realistic gain ~20 to 30% via stricter structure. Keeping a form humans edit in sync with a form Claude reads introduces drift risk. BPE tokenization already compresses common markdown chars well. Not enough ROI at personal template scale. Revisit if the cap becomes a binding constraint again.
- **Threshold based on tokens instead of lines.** Same rejection as ADR-002. Lines remain easier to reason about at a glance. Revisit if observed degradation makes lines the wrong unit.
- **Empirical sweep via `llm-eval`** (or a future task routing benchmark). Highest rigor, but a harness for measuring `AI_CONTEXT.md` retrieval directly doesn't exist yet. ADR-004 is a working pragmatic choice meant to be superseded by a measured one when data is available.
