# Fixtures

One directory per task fixture, grouped by family.

```
bench/tasks/<family>/<task-id>/
├── prompt.md     # what the model is asked to do (verbatim — the runner pipes this in)
├── setup.sh      # read-only init for the worktree (e.g. install deps, scaffold inputs)
├── oracle/       # judge inputs — shape depends on the family
└── meta.json     # { family, timeout_seconds, success_criteria, notes }
```

`prompt.md` is the surface the model sees. Don't bias the prompt toward any model. It should read identically to one a Claude Code user would actually type.

## V1 families

| Family | `oracle/` contents | Judge |
|---|---|---|
| `refactor`   | `golden-before.cmd` (the deterministic command), or a script local to the fixture | The `verify-refactor` skill: capture, refactor, capture, `diff -u`. Empty diff = pass. |
| `explore`    | `expected.json`: `[{ "file": "src/auth.ts", "line": 42 }, ...]` | F1 over the reported set vs. expected. `score` = F1. `pass` = F1 ≥ 0.8. |
| `test-write` | `failing_test.<ext>` (the test that should turn green) and `test_cmd` in `meta.json` | Run full suite. `pass` = failing test green AND no other test regresses. |

## Fixture authoring rules

- **Determinism first.** No clocks, no random IDs, no network. Normalize before diffing if the underlying tool can't be made deterministic.
- **Small fixtures.** Each one should run in well under its family's timeout, on Haiku, on cold cache. If it doesn't, split it.
- **Don't tune the prompt for one model.** If the prompt only works on Opus, the result tells you nothing about routing.
- **Pin runtime via `setup.sh`.** Lock dependency versions so reruns months later still pass.

## Fixture work for V2 and V3

Fixture corpus is **not** part of V1 (design only). When the V2 runner ships, target 3 to 5 fixtures per family. That's enough to compute meaningful aggregates per family without the corpus dominating Claude Code's context budget.
