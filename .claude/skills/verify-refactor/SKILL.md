---
name: verify-refactor
description: Prove a refactor preserved behavior by diffing deterministic output captured before and after the change. Use before trusting any refactor of load-bearing, deterministic code (a report, transform, backtest, codegen step).
argument-hint: "[command that produces deterministic output]"
---

Goal: prove the change is behavior-preserving with evidence stronger than "tests still pass" — byte-identical output.

Let `$ARGUMENTS` be the command that produces deterministic output (e.g. `npm run report -- --fixture sample`). If none was given, ask the user for it, or infer it from the project's scripts.

1. **Baseline (before any edits).** On the pre-refactor code, run the command and capture output to a temp file:
   - `<command> > /tmp/golden-before.txt 2>&1`
   - If you've already edited, stash or check out the original first (`git stash` / `git worktree`), capture, then restore.
2. **Refactor.** Make the change. Touch only what the refactor requires (see surgical-scope rule in CLAUDE.md).
3. **After.** Re-run the same command: `<command> > /tmp/golden-after.txt 2>&1`.
4. **Diff.** `diff -u /tmp/golden-before.txt /tmp/golden-after.txt`.
   - **Empty diff** → behavior preserved. Report success.
   - **Non-empty diff** → either a bug in the refactor (fix it) or an intended change (then this wasn't a pure refactor — call that out explicitly and get the change reviewed).

If output is nondeterministic (timestamps, ordering, ids), normalize both sides the same way (sort, strip volatile fields) before diffing — and note what you normalized.

Tie-in: if production and an offline replay share the *exact* same implementation (don't-duplicate rule), the replay *is* a golden-output harness for production refactors. See @templates/LLM_APP_DEVELOPMENT_BEST_PRACTICES.md (#testing--validation).
