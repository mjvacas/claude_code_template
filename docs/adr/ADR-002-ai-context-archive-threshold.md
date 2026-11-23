# ADR-002: AI_CONTEXT.md archive threshold = 500 lines

## Status

Superseded by [ADR-004](./ADR-004-ai-context-archive-threshold-bump.md) (2026-06-09).

Original status: Accepted (2026-06-06). Superseded after the 500 line cap was found to trigger archival friction often enough in practice that the retrieval cost it guarded against was no longer the binding constraint. The math in this ADR remains correct. ADR-004 raises the cap to 750 and pairs it with a `/handoff` state sufficiency requirement so archival stays safe at the higher number.

## Context

`AI_CONTEXT.md` loads automatically into every Claude Code session via
`@AI_CONTEXT.md` in `CLAUDE.md`, so its size is a per session tax on the
attention budget. Without a defined trigger for archival to
`docs/summaries/YYYY-MM.md`, the file grows unbounded and silently degrades
session quality.

A "Keep it scannable; archive when long" convention existed but was unenforced.
This session added two layers of enforcement (a SessionStart hook nag and a
`/handoff` archive step) and needed a concrete threshold. The first number
considered (1000 lines) was a guess. This ADR records the replacement, anchored
in evidence.

### Evidence

- **Lost in the Middle research, peer reviewed and replicated across 6 model
  families including Claude.** Retrieval accuracy degrades by >30% when the
  relevant span sits in the middle of the input, with the inflection around
  **~10k tokens of total context**.
  ([Arize paper reading](https://arize.com/blog/lost-in-the-middle-how-language-models-use-long-contexts-paper-reading/),
  [OpenReview](https://openreview.net/forum?id=XSHP62BCXN))
- **Anthropic: Best practices for Claude Code.** No numerical CLAUDE.md cap is
  published, but the qualitative guidance is unambiguous: *"keep it short,"*
  *"bloated CLAUDE.md files cause Claude to ignore your actual instructions,"*
  prune ruthlessly. ([code.claude.com/docs/en/best-practices](https://code.claude.com/docs/en/best-practices))
- **Anthropic: Effective context engineering for AI agents.** Frames the goal
  as *"the smallest possible set of high-signal tokens that maximize the
  likelihood of [the] desired outcome."*
  ([anthropic.com/engineering/...](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents))
- **Community CLAUDE.md sizing.** Several practitioner sources cite "~200 lines"
  as a working CLAUDE.md cap. One benchmark reports a CLAUDE.md rewrite from
  3,847 to 312 tokens (91.9% reduction) with no quality regression.
  ([MindStudio](https://www.mindstudio.ai/blog/claude-code-token-management-hacks),
  [Firecrawl](https://www.firecrawl.dev/blog/claude-code-token-efficiency)).
  Treated here as supporting evidence only, because these numbers are not in
  Anthropic's official docs.

### Derivation

Decision log prose runs ~10 to 15 tokens per line (an estimate, since this
project hasn't yet measured its own ratio). Using ~12 tokens per line:

| Lines | ≈ Tokens | Notes |
|------:|---------:|-------|
| 200   | 2.4k     | Matches the community CLAUDE.md norm |
| 300   | 3.6k     | Conservative AI_CONTEXT.md budget |
| **500** | **6.0k** | **Chosen (see below)** |
| 833   | 10.0k    | Lost in the Middle inflection point |
| 1000  | 12.0k    | Past the inflection before any other context |

The 10k token safe attention envelope is *total*. It has to cover
`AI_CONTEXT.md`, `CLAUDE.md`, recalled auto memories, the diff, and active
conversation. A 500 line (~6k token) `AI_CONTEXT.md` keeps ~4k tokens for
everything else inside the safe zone. That's tight but workable. It also leaves
margin as model attention scales. 1M token windows are already standard on Opus
4.7+. The Lost in the Middle threshold should rise with newer models.

A more conservative 300 line cap was also defensible. 500 was chosen to hold up
as model capacity grows, at the cost of a slightly larger per session tax
today.

## Decision

`AI_CONTEXT.md` archives to `docs/summaries/YYYY-MM.md` once it exceeds
**500 lines**. Enforcement has two layers:

- `.claude/hooks/session-context.sh` emits a one line nag at SessionStart when
  the file is over the threshold (silent below).
- `.claude/commands/handoff.md` (the `/handoff` skill) instructs the model to
  archive oldest blocks before committing if the file is over the threshold.

The number is a single source of truth. Changing it requires updating the hook,
the `/handoff` command, the `AI_CONTEXT.md` header, and
`templates/AI_SESSION_START.md` together. It also requires superseding this ADR.

## Consequences

- Archival becomes a routine, prompted event rather than a forgotten chore.
- The number is auditable and can be derived again. Future readers see the
  evidence chain instead of a guess.
- The per session token cost of a maxed out `AI_CONTEXT.md` is ~6k tokens. The
  combined context that loads automatically stays inside the Lost in the Middle
  safe zone for current models.
- Tradeoff: the 12 tokens per line ratio is an estimate. A project whose
  decision log prose is denser (lots of code blocks, JSON, tables) will hit the
  token ceiling at fewer lines than this. If observed degradation suggests the
  line count is the wrong unit, supersede with a threshold based on tokens.

## Alternatives Considered

- **1000 lines.** The initial guess. Rejected: ≈12k tokens, past the documented
  Lost in the Middle inflection point before any other context is added.
- **300 lines.** The most conservative defensible number, matching ~2× the
  community CLAUDE.md norm. Rejected only as the default because it doesn't hold
  up as attention budgets grow. It remains a reasonable choice for projects
  running hot context.
- **No threshold, rely on convention.** Rejected: the convention existed and
  was being ignored, including by the maintainer.
- **Empirical sweep via `llm-eval` and `tune-parameters`.** Considered. The
  harness would have produced a more rigorous number but requires real session
  blocks to sweep over (which don't yet exist) and would be overkill given the
  estimate anchored in research is within an order of magnitude of any plausible
  empirical result. Worth revisiting if downstream adoption produces enough
  data to make the sweep meaningful.
- **Threshold based on tokens instead of lines** (e.g., `wc -c` / 4). More
  accurate but harder to reason about ("am I close to the limit?" is a
  scannable question for lines, less so for tokens). Revisit if line count
  proves to be a misleading proxy.
