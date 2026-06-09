# AI Context — Human-Curated Decision Log

> The **human-curated** half of this project's hybrid memory. It holds decisions,
> rationale, open questions, and next steps — the things a future reader can't
> reconstruct from the diff. Claude's native auto-memory handles the *other* half
> (learned patterns, build quirks); don't duplicate those here.
>
> Auto-loaded into every session via `@AI_CONTEXT.md` in `CLAUDE.md`. Update it with
> `/handoff` at the end of a session and commit it **together with the code**.
> Keep it scannable; archive old session blocks to `docs/summaries/YYYY-MM.md` once
> this file exceeds ~750 lines (the SessionStart hook nags above that, and `/handoff`
> archives before committing). Archival is safe because `/handoff` requires each
> session block to be state-sufficient for cold pickup. Threshold rationale:
> [ADR-004](docs/adr/ADR-004-ai-context-archive-threshold-bump.md) (supersedes [ADR-002](docs/adr/ADR-002-ai-context-archive-threshold.md)).

---

## Session YYYY-MM-DD

### Summary
One line: what this session was about.

### Decisions
- **Decision:** what was decided
  - **Why:** rationale
  - **Alternatives:** what was rejected and why
  - (If significant or hard to reverse, also write an ADR under `docs/adr/`.)

### Open Questions
- Q: … — options: [A, B] — need to decide by/when.

### Next Steps
1. …
2. …

---

<!-- Add the newest session block at the top. Older blocks move down, then to
     docs/summaries/ once this file gets long. -->
