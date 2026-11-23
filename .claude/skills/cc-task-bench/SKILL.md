---
name: cc-task-bench
description: Benchmark Claude Code task performance — pass-rate × tokens × wall-clock × cost across Opus, Sonnet, Haiku on a fixed task corpus. V1 is the method only (no runner yet). Use to design a benchmark that decides which model routes which task type, or to validate a routing claim with data instead of vibes.
argument-hint: "[task family or task-id to design for; default: all V1 families]"
---

Goal: measure, then pick the cheapest model that's good enough.

**Status:** V1 is the method only (`docs/adr/ADR-003-cc-task-bench-scope.md`). There's no runner and no fixtures yet, and every price in `bench/pricing.json` is null, so nothing can run. Use this to design a benchmark, with the schema in `bench/README.md`.

1. **Pin the bench commit.** Every attempt records `bench_commit` (git sha of the runner) and `git_sha_of_attempt` (worktree HEAD). Reruns against the same fixtures stay comparable across days.
2. **One worktree per attempt.** Spin a fresh git worktree under `.worktrees/<run-id>/<model>/<task>/<n>/` so attempts can't contaminate each other. Results land separately in `bench/results/<run-id>/<model>/<task>/`. Tear the worktree down after capturing artifacts.
3. **Run a deterministic judge per V1 task family.**
   - **Refactor** → `verify-refactor` skill verbatim: capture `command > /tmp/golden-before.txt`, refactor, capture `/tmp/golden-after.txt`, `diff -u`. An empty diff is a pass.
   - **Exploration** → F1 over reported `file:line` set vs the fixture's `oracle/expected.json`.
   - **Test writing** → originally failing test turns green AND no other test in the suite regresses. Run the full suite.
4. **Record metrics per attempt.** Status, score, token usage (input, output, cache read, cache write), wall clock time, tool call count, derived cost (via `bench/pricing.json`), the judge block, and any error. Authoritative schema: `bench/README.md`.
5. **Aggregate per cell.** 5 attempts per (model, task). Report pass rate AND consistency (score stdev) **separately**. Never collapse them.
6. **Read the surface, don't argmax.** Apply `tune-parameters` philosophy when interpreting results. Pick the model that sits in a stable region of (cost × pass rate), not the model that wins one noisy cell.

V3 adds rubric judged families via `llm-eval` as an ensemble of 3 judges. V1 sticks to deterministic families on purpose, because debugging rubric pipelines and the model matrix at the same time is a known antipattern.

Attribution: harness shape (worktree isolation, separate dimensions, ≥3 runs, commit pinning, token accounting per attempt) adapted from [affaan-m/ECC](https://github.com/affaan-m/ECC)'s `agent-eval` methodology, with one correction. Pass rate and consistency are reported as separate axes and aren't collapsed into one number.
