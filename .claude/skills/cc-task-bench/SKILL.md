---
name: cc-task-bench
description: Benchmark Claude Code task performance — pass-rate × tokens × wall-clock × cost across Opus, Sonnet, Haiku on a fixed task corpus. Use to decide which model routes which task type, or to validate a routing claim with data instead of vibes.
argument-hint: "[task family or task-id; default: run all V1 families]"
---

Goal: pick the cheapest model that's good enough — measured, not guessed.

1. **Pin the bench commit.** Every attempt records `bench_commit` (git sha of the runner) and `git_sha_of_attempt` (worktree HEAD). Re-runs against the same fixtures stay comparable across days.
2. **One worktree per attempt.** Spin a fresh git worktree under `.worktrees/<run-id>/<model>/<task>/<n>/` so attempts can't contaminate each other. Results land separately in `bench/results/<run-id>/<model>/<task>/`; tear the worktree down after capturing artifacts.
3. **Run a deterministic judge per V1 task family.**
   - **Refactor** → `verify-refactor` skill verbatim: capture `command > /tmp/golden-before.txt`, refactor, capture `/tmp/golden-after.txt`, `diff -u`; empty diff = pass.
   - **Exploration** → F1 over reported `file:line` set vs the fixture's `oracle/expected.json`.
   - **Test writing** → originally-failing test turns green AND no other test in the suite regresses. Run the full suite.
4. **Record per-attempt metrics.** Status, score, token usage (input / output / cache read / cache write), wall-clock, tool-call count, derived cost (via `bench/pricing.json`), the judge block, and any error. Authoritative schema: `bench/README.md`.
5. **Aggregate per cell.** 5 attempts per (model, task). Report pass-rate AND consistency (score stdev) **separately** — never collapsed.
6. **Read the surface, don't argmax.** Apply `tune-parameters` philosophy when interpreting results: pick the model that sits in a robust region of (cost × pass-rate), not the model that wins one noisy cell.

V3 adds rubric-judged families via `llm-eval` as a 3-judge ensemble; V1 is deterministic-only on purpose — debugging rubric pipelines and the model matrix at the same time is a known anti-pattern.

Attribution: harness shape (worktree isolation, separate dimensions, ≥3 runs, commit pinning, per-attempt token accounting) adapted from [affaan-m/ECC](https://github.com/affaan-m/ECC)'s `agent-eval` methodology, with one correction — pass-rate and consistency are reported as separate axes, not collapsed into one number.
