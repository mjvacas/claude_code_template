# ADR-007: AI_CONTEXT.md archive threshold = 1000 lines

## Status

Accepted (2026-11-18) — supersedes [ADR-004](./ADR-004-ai-context-archive-threshold-bump.md). Keeps ADR-004's `/handoff` state-sufficiency requirement unchanged.

## Context

[ADR-004](./ADR-004-ai-context-archive-threshold-bump.md) set the cap at 750 lines (~9k tokens at 12 tokens per line) to stay inside a "10k-token attention-safe envelope" taken from the 2023 lost-in-the-middle research ([ADR-002](./ADR-002-ai-context-archive-threshold.md)). Three of its inputs no longer hold:

- **Models.** Every current Claude model has a 1M-token context window; the older Haiku 4.5 has 200K. The 2023 research tested earlier models. The 10k envelope was also never met in practice: Claude Code's own system prompt and tool definitions are larger than that before any project file loads.
- **Density.** Measured across seven projects that use the template, `AI_CONTEXT.md` runs about 15–26 tokens per line (estimated at 4 characters per token), not 12. A 750-line file is already ~11–20k tokens.
- **Friction.** Those projects made 1,204 commits to `AI_CONTEXT.md`, 66 of them archives. One archived about 6 times a month, and two sat above 750 lines when this was measured.

More context still isn't free. Reliability drops gradually as input grows ([Chroma, *Context Rot*, 2025](https://trychroma.com/research/context-rot)), and Anthropic's [context engineering guidance](https://anthropic.com/research/effective-context-engineering-for-ai-agents) treats context as an attention budget. Neither gives a threshold, so the number comes from the friction side, measured.

## Method

Each project's `AI_CONTEXT.md` line count was replayed commit by commit against caps from 500 to 2,000. Growth between commits was applied in order, with the real archives (drops of at least 15% and 50 lines) taken out. When a commit left the file above the cap, it was archived under two policies, so the result doesn't rest on one assumption:

- **A:** down to 60% of the cap (the median of the real archives).
- **B:** down to 478 lines (the median size left after a real archive).

Metrics: archives per month (friction) and the mean size loaded per session, counting one session per `AI_CONTEXT.md` commit, in tokens at each project's measured density. At 750 lines the model predicts about 2.0 archives a month per project; the real average was 1.6.

| Cap | Archives/month, avg (A / B) | Mean tokens loaded (A) | Extra tokens per archive avoided per month (A) |
|----:|----------------------------:|-----------------------:|-----------------------------------------------:|
| 750 | 1.98 / 2.23 | ~10.3k | ~3.4k |
| 900 | 1.66 / 1.40 | ~11.6k | ~4.1k |
| **1000** | **1.42 / 1.15** | **~13.0k** | **~5.5k** |
| 1250 | 1.12 / 0.77 | ~14.9k | ~6.1k |
| 1500 | 0.89 / 0.58 | ~17.6k | ~11.6k |
| 2000 | 0.60 / 0.36 | ~21.5k | ~15.6k |

The last column compares each cap with the previous cap in the full sweep, which also ran 500, 600, 1100 and 1750.

The curve is smooth and falls steadily under both policies and in both halves of the history (the earlier half is noisier). There's no sharp knee and no lone good value. Under policy A over the whole history, the cost of each avoided archive stays moderate up to about 1,250 lines and roughly doubles past it. Under policy B it jumps at 1,250, and in the recent half of the history at 1,100. So the acceptable region is 900–1,250, and 1,000 is the value that holds under every variant.

## Decision

1. **Threshold: 1000 lines**, the middle of the acceptable region. That's about 12–13k tokens loaded per session on average and ~15–26k at the cap, 1.5–2.6% of a 1M window.
2. **ADR-004's state-sufficiency requirement and two-layer enforcement stay as they are**: the SessionStart hook reminds above the cap, and `/handoff` archives the oldest blocks before committing.
3. The number is a single source of truth. Changing it means updating the hook, the `/handoff` command, the `AI_CONTEXT.md` header, `templates/AI_SESSION_START.md`, `docs/token-awareness.md` and the CLAUDE.md ADR highlight, adding a Migration item for adopters, and superseding this ADR.

## Consequences

- About 30–50% fewer archives than at 750, for about 2k more tokens per session.
- A project that writes much faster than the rest (one wrote ~3,000 lines a month, five times the others) archives often at any cap: about 6 times a month at 1,000 and 3 at 2,000. Its fix is shorter session blocks, not a bigger cap.
- On a 200K-window model, a full file is about 8–13% of the window.
- **The quality cost is unmeasured.** Nothing yet measures how well Claude uses a 13–26k-token `AI_CONTEXT.md`. Supersede this with measured data once an eval (the `cc-task-bench` V2 runner or an `llm-eval` harness) can.
- Lines remain a rough proxy: density varies 1.7× between projects. If a project runs much denser, a size cap (for example ~80 KB, about 20k tokens) is the next step.
- The estimates are approximate: 4 characters per token, and current tokenizers can count up to ~35% more. Counting one session per commit undercounts sessions, not the size each one loads.

## Alternatives Considered

- **Keep 750 lines (ADR-004).** Rejected: its 10k-token rationale no longer holds, and the archive churn is measured.
- **1250 lines.** At the top of the region. Not chosen because the cost per avoided archive already jumps there under policy B (and at 1,100 in the recent half), while 1,000 holds under every variant.
- **1500 lines or more.** Rejected: each avoided archive costs about twice as many tokens per session.
- **A size-based cap (bytes or tokens).** More accurate across densities. Not chosen yet because lines are easy to check at a glance (`wc -l`), and the hook and `/handoff` already count them. Revisit if the density spread causes trouble.
- **No cap, relying on state-sufficient blocks alone.** Rejected: files grow without bound, and the replay shows how fast.
