# ADR-003: cc-task-bench — V1 scope, model matrix, scoring

## Status

Accepted (2026-06-08)

## Context

`claude_code_template` ships three eval / refactor primitives — [`llm-eval`](../../.claude/skills/llm-eval/SKILL.md), [`verify-refactor`](../../.claude/skills/verify-refactor/SKILL.md), and [`tune-parameters`](../../.claude/skills/tune-parameters/SKILL.md) — but no harness for answering the *routing* question: **for this Claude Code task type, which model is cheapest while still good enough?**

External prior art exists. The [`affaan-m/ECC`](https://github.com/affaan-m/ECC) repository ships [`the-longform-guide.md`](https://github.com/affaan-m/ECC/blob/main/the-longform-guide.md) with a prescriptive routing table (Haiku for simple tasks, Sonnet for balanced, Opus for complex) and an [`agent-eval`](https://github.com/affaan-m/ECC/tree/main/skills/agent-eval) skill with a reproducible methodology (worktree isolation, ≥3 runs per cell, separate cost / pass-rate / wall-clock dimensions, commit pinning). The routing table is **advice**, not a measured result — derived from one practitioner's daily use, with no public per-attempt data behind it.

Two adjacent benchmarks are deliberately scope-separated:

- **A domain-accuracy benchmark** measures whether a feature's *output* is correct (e.g. extraction accuracy of a Claude-API feature). Out of scope here.
- **`cc-task-bench`** (this ADR) measures **Claude Code task performance** — general coding work driven through the CLI.

### Why now

Token-awareness is a pre-public-release gate for this template. Without a measurement harness, the project ships either a guessed routing recommendation or none. Either weakens the template's measurement-first stance — itself the rationale for shipping `llm-eval`, `verify-refactor`, and ADR-002's lost-in-the-middle derivation.

## Decision

V1 ships the **measurement methodology and fixture layout**, not the runner. The runner is V2.

**Task families (V1)** — three deterministic-judge families only:

1. **Refactor** — diff-baseline scoring via the existing `verify-refactor` skill (cited verbatim from the runner).
2. **Code exploration** ("where is X defined") — F1 over reported `file:line` set vs. a golden index per fixture.
3. **Test writing from a failing repro** — originally-failing test turns green; no other test in the suite regresses.

Rubric-judged families (code review, planning, session orient, commit-message authoring) defer to V2/V3 to avoid debugging rubric pipelines and the model matrix simultaneously.

**Model matrix:** Opus 4.8, Opus 4.7, Sonnet 4.6, Haiku 4.5. Including both Opus revisions characterizes the 4.7 → 4.8 delta as part of the deliverable.

**Runs per cell:** 5, not 3. ECC says ≥3; 5 lets us compute IQR + stdev cleanly so consistency reporting is stable enough to act on. Total V1: 3 × 4 × 5 = **60 attempts per run**.

**Scoring discipline:** pass-rate and consistency are reported as separate axes — never collapsed into one number. Per-attempt token accounting is required (input, output, cache-read, cache-write). Cost is derived from a versioned `bench/pricing.json`, pinned per run by `bench_commit`.

**Fixtures:** in-repo at `bench/tasks/<family>/<task-id>/`. Revisit at V3 if the corpus bloats the template.

**File layout:**

- `.claude/skills/cc-task-bench/SKILL.md` — the methodology (≤30 lines, mirrors the other three skills' shape).
- `bench/` — artifacts: README + schema, fixture corpus, runner (V2), results.
- `docs/adr/ADR-003-cc-task-bench-scope.md` — this file.

## Consequences

- The project ships measurement **capability** in V1 before measurement **data** in V2. Adopters can read the methodology, design fixtures locally, and form a model-routing plan before any API cost is incurred.
- Each V1 run costs real dollars — 60 attempts × wall-clock × API rates. Rough order: small fixture corpus → single-digit USD per run; a larger corpus → double digits. CI integration is deferred to V2 with a smoke mode (1 run × 1 task per family) so PR gating doesn't bankrupt adopters.
- Rubric-judged families staying out of V1 means commit-message authoring, planning, session-orient, and code review get no immediate data. Adopters routing those tasks rely on the ECC table (and judgment) until V3.
- Including both Opus 4.7 and 4.8 doubles the Opus column's cost compared to a 4.8-only matrix. Justified by the explicit deliverable: characterizing the 4.7 → 4.8 capability/cost delta.
- The harness becomes the data substrate for the eventual dashboard envisioned in the plan — `summary.json` is the contract a dashboard would consume.
- Trade-off: 5 runs per cell costs ≈67% more than ECC's minimum of 3. Accepted because the consistency metric becomes too noisy at n=3 to act on.

## Alternatives Considered

- **Inherit ECC's routing table without measuring.** Rejected: the table is prescriptive, derived from one practitioner's daily use, with no public methodology and no per-attempt data behind it. Inheriting weakens the template's measurement-first stance.
- **V1 = refactor only (minimum real comparison).** Considered: 4 models × 1 family × 5 runs = 20 attempts; cheaper and faster. Rejected because three deterministic families exercise three scoring paths on day one, validating the methodology end-to-end before V2 expands it.
- **3 runs per cell (ECC minimum).** Rejected: consistency metric is too noisy at n=3 to drive routing decisions.
- **Opus 4.8 only (drop 4.7).** Cheaper. Rejected because the 4.7 → 4.8 delta is itself a user-facing routing question — including both makes the answer a deliverable.
- **Rubric judges in V1.** Rejected: debugging rubric pipelines and the model matrix simultaneously is a known anti-pattern. Deferred to V3 via an `llm-eval` 3-judge ensemble.
- **Sidecar fixtures repo, vendored per [ADR-001](./ADR-001-vendor-with-source-pin.md).** Rejected for V1: premature separation. Revisit at V3 if the corpus bloats the template.
- **Live pricing source vs. hardcoded `pricing.json`.** Rejected live: hardcoded keeps runs reproducible — historical results re-cost cleanly by editing the file and re-running aggregation.
- **Pure binary pass/fail (ECC default).** Rejected as the only mode: deterministic families pass/fail, but the eventual rubric families need partial-credit `score` ∈ [0,1]. Schema supports both from V1 to avoid a migration later.
