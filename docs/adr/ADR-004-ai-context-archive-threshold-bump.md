# ADR-004: AI_CONTEXT.md archive threshold = 750 lines + `/handoff` state-sufficiency requirement

## Status

Accepted (2026-06-09) — supersedes [ADR-002](./ADR-002-ai-context-archive-threshold.md).

## Context

[ADR-002](./ADR-002-ai-context-archive-threshold.md) set the threshold at **500 lines**, derived from the lost-in-the-middle research (>30% retrieval degradation past ~10k tokens of total context) and a 12 tok/line decision-log prose estimate. The math: 500 × 12 = 6k tokens for `AI_CONTEXT.md`, leaving ~4k tokens for everything else (CLAUDE.md, recalled auto-memories, the diff, the active conversation) inside the 10k attention-safe envelope.

The math is still correct. The choice is being revisited because **the 500-line cap is hit often enough in practice that archival friction (SessionStart nag, mid-flow `/handoff` interruption, more compression work per session) outweighs the retrieval cost it was guarding against — sometimes after a single long session.**

A naive bump to 1000 was considered and rejected: it would sacrifice ADR-002's full retrieval-cost headroom for friction relief, when a smaller bump can capture most of the friction relief without paying the full retrieval price.

### The deeper insight

The right knob to relax isn't just "the cap" — it's the implicit contract that older blocks need to stay loaded. A session block can be archived at any time without losing operational continuity **as long as the latest block is self-sufficient for cold pickup.** The friction at 500 wasn't really about losing information; it was about being forced to archive mid-session when the latest block hadn't yet captured everything the next session would need.

This decouples two things ADR-002 conflated:

- **How much do we want auto-loaded each session?** A token-budget question — answered by the line cap.
- **What guarantees that archival doesn't lose continuity?** A handoff-discipline question — answered by the state-sufficiency requirement.

## Decision

Two coupled changes:

1. **Threshold: 750 lines** (~9k tokens at the 12 tok/line estimate). Tight headroom above ADR-002's 6k, still inside the 10k attention-safe envelope when CLAUDE.md and recalled auto-memory are kept lean.

2. **`/handoff` state-sufficiency requirement.** Each handoff produces a session block whose **Current State + Decisions + Open Questions + Next Steps** are sufficient for a cold-start `/session-start` to resume *without reading archived summaries*. The `/handoff` command checklist names this requirement explicitly. Archival is safe under this contract because the latest block alone carries operational continuity.

Enforcement remains two-layered (SessionStart hook nag + `/handoff` archive step). The number is a single source of truth: changing it requires updating the hook, the `/handoff` command, the `AI_CONTEXT.md` header, `templates/AI_SESSION_START.md`, the CLAUDE.md ADR highlight, and superseding this ADR.

## Consequences

- **Per-session token tax for a maxed `AI_CONTEXT.md` rises ~50%** — ~6k → ~9k tokens. Combined auto-loaded context stays inside the 10k attention-safe envelope under normal conditions; long sessions on smaller-context models may occasionally cross it.
- **Archival friction drops** — fewer SessionStart nags, less mid-flow `/handoff` archival; one long productive session no longer routinely blows past the cap.
- **Handoff discipline tightens.** State-sufficiency isn't a soft suggestion — it's the load-bearing assumption that makes 750 + archival safe. A handoff that ships a vague "Next Steps" block silently violates the assumption and degrades cold-start quality.
- The 12 tok/line estimate is still load-bearing. A project whose decision-log prose runs denser (heavy code blocks, JSON, tables) will hit the token ceiling at fewer lines than this — supersede with a token-based threshold if that's observed.
- If 750 turns out to be the wrong number in practice, supersede again — ideally with empirical data from a future measurement harness rather than another estimate.

## Alternatives Considered

- **Keep 500 lines (ADR-002).** Rejected: in practice the cap is hit often enough that archival friction outweighs the retrieval cost. ADR-002's math is still correct; this ADR explicitly accepts the trade documented there, but only partway — choosing 750 rather than 1000 keeps most of the retrieval headroom intact.
- **Bump to 1000 lines.** Considered. Would relieve friction more completely but sacrifices ADR-002's full retrieval-cost headroom — `AI_CONTEXT.md` alone would land at ~12k tokens, past the lost-in-the-middle inflection before any other context is added. The state-sufficiency requirement makes the additional headroom unnecessary: archival is already safe.
- **Smaller session blocks + faster archival cadence** (per-block hygiene instead of per-file ceiling). Considered — same goal (reduce friction) via shorter blocks and monthly archival regardless of file size. Subsumed by the state-sufficiency requirement, which already encourages tight latest-blocks and makes aggressive archival safe.
- **Selective loading via `/session-start`** (don't auto-load `AI_CONTEXT.md` at all; read only relevant blocks on demand). Considered. Bigger token win, but selective loading risks missing important details from older blocks the heuristic doesn't surface. Auto-loading the (modestly larger) capped file plus a self-sufficient latest block gives better worst-case correctness for personal-template scale.
- **Re-encoding to a denser machine-targeted format** (JSON, terse shorthand, "byte code"). Considered. Realistic gain ~20–30% via stricter structure; sync between a human-edit form and a Claude-read form introduces drift risk; BPE tokenization already compresses common markdown chars well. Not enough ROI for personal-template scale; revisit if cap re-emerges as a binding constraint.
- **Token-based threshold instead of line-based.** Same rejection as ADR-002 — lines remain easier to reason about at a glance. Revisit if observed degradation makes lines the wrong unit.
- **Empirical sweep via `llm-eval`** (or a future task-routing benchmark). Highest rigor, but a harness for measuring `AI_CONTEXT.md` retrieval directly doesn't exist yet. ADR-004 is a working pragmatic choice meant to be superseded by a measured one when data is available.
