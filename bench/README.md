# cc-task-bench

Benchmark for Claude Code task performance across Opus 4.7, Opus 4.8, Sonnet 4.6, and Haiku 4.5.

Measures **pass-rate × tokens × wall-clock × cost** on a fixed task corpus, so model routing for everyday Claude Code work becomes a data decision instead of a guess.

- **Methodology:** [`.claude/skills/cc-task-bench/SKILL.md`](../.claude/skills/cc-task-bench/SKILL.md)
- **Scope and rationale:** [ADR-003](../docs/adr/ADR-003-cc-task-bench-scope.md)

## Status

**V1 — design artifacts only.** This file, the skill, the pricing schema, the ADR, and the fixture layout document below. The runner is V2 work; no runs have happened yet.

## Layout

```
bench/
├── README.md              # this file
├── pricing.json           # per-model $/Mtok, pinned per run via bench_commit
├── tasks/                 # fixture corpus
│   ├── README.md          # fixture shape per family
│   └── <family>/<task-id>/
│       ├── prompt.md      # what the model is asked to do
│       ├── setup.sh       # read-only init for the fixture worktree
│       ├── oracle/        # judge inputs (see family table below)
│       └── meta.json      # family, timeout, success criteria
├── runner/                # orchestrator (V2)
└── results/<run-id>/      # per-run artifacts (gitignored except INDEX.md)
    └── <model>/<task>/
        ├── <attempt-n>.json
        └── cell.json
```

## V1 task families

| Family | Scoring | Oracle | Timeout |
|---|---|---|---|
| `refactor`   | Diff-baseline (byte-identical) | `verify-refactor` skill verbatim | 5 min |
| `explore`    | F1 over reported `file:line` set | `oracle/expected.json` | 2 min |
| `test-write` | Originally-failing test green; no regressions | `oracle/failing_test.<ext>` + full suite | 3 min |

Deferred to V2 (rubric-or-corpus dependent): code review (planted-bug recall), multi-file edits with constraint preservation.
Deferred to V3 (rubric-judged via `llm-eval` ensemble): planning, session orient, commit-message authoring.

## Model matrix

4 models × 3 families × 5 runs = **60 attempts per V1 run**.

| Model ID | Tier | Why included |
|---|---|---|
| `claude-opus-4-8`           | Frontier | Current top tier |
| `claude-opus-4-7`           | Frontier (prior) | Characterizes the 4.7 → 4.8 delta |
| `claude-sonnet-4-6`         | Mid | Likely default for most adopters |
| `claude-haiku-4-5-20251001` | Cheap | Cost-floor anchor; routing target for cheap tasks |

5 runs per cell (ECC says ≥3) so IQR + stdev consistency reporting is stable enough to act on.

## Schema

### Per-attempt JSON
`results/<run-id>/<model>/<task>/<attempt-n>.json`

```json
{
  "schema_version": 1,
  "run_id": "2026-06-08T14:22Z-a3f9",
  "bench_commit": "<git sha of runner>",
  "model": "claude-opus-4-8",
  "task_family": "refactor",
  "task_id": "rename-symbol-001",
  "attempt": 3,
  "worktree_path": ".worktrees/<run-id>/<model>/refactor/rename-symbol-001/3",
  "status": "pass",
  "score": 1.0,
  "tokens": { "in": 8421, "out": 1203, "cache_read": 0, "cache_write": 0 },
  "wall_clock_ms": 41200,
  "tool_calls": 27,
  "cost_usd": 0.0934,
  "judge": {
    "kind": "diff-baseline",
    "verdict": "byte-identical",
    "artifact": "diffs/attempt-3.diff"
  },
  "git_sha_of_attempt": "<git sha of worktree HEAD>",
  "error": null
}
```

`status` ∈ `pass | fail | error | timeout`. `judge.kind` ∈ `diff-baseline | f1 | test-suite | rubric` — one per V1 family (rubric reserved for V3); `judge.verdict` carries the family-specific outcome.

### Cell aggregate
`results/<run-id>/<model>/<task>/cell.json`

```json
{
  "model": "claude-opus-4-8",
  "task_id": "rename-symbol-001",
  "n": 5,
  "pass_rate": 0.8,
  "score_mean": 0.84, "score_median": 1.0, "score_iqr": [0.0, 1.0],
  "tokens_in":  { "mean": 8210, "p50": 8100, "p95": 9800 },
  "tokens_out": { "mean": 1180, "p50": 1100, "p95": 1500 },
  "wall_clock_ms": { "mean": 40100, "p50": 39200, "p95": 52000 },
  "cost_usd":  { "mean": 0.091, "total": 0.455 },
  "consistency": { "score_stdev": 0.36, "any_error": false }
}
```

`pass_rate` and `consistency` are surfaced as separate axes. Collapsing them — ECC's anti-pattern — hides whether a model fails because it gets things wrong or because it's inconsistent.

### Model summary
`results/<run-id>/<model>/summary.json` — per-family pass-rate, weighted total cost, latency p50/p95, and a `vs_baseline` block comparing the previous run's same-model results when present.

### Run INDEX
`results/<run-id>/INDEX.md` — human-readable summary table + a **hypothesis-check** section noting where this run agrees or disagrees with ECC's prescriptive routing table. Force-added per run (`git add -f bench/results/<run-id>/INDEX.md`); raw per-attempt JSON is gitignored.

## Running

Runner ships in V2. The shape will be roughly `bench/runner/run.sh --family <name> --models all --runs 5`. The schema above is the data contract; the runner produces it, dashboards consume it.

## Attribution

Harness methodology — worktree isolation per attempt, separate pass-rate / cost / wall-clock dimensions, ≥3 runs per cell, pinned `bench_commit`, per-attempt token accounting — adapted from the [affaan-m/ECC](https://github.com/affaan-m/ECC) benchmark. ECC's prescriptive model-routing table is treated as a hypothesis this benchmark tests, not a result it inherits.
