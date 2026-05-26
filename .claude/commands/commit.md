---
description: Stage and commit the current work as one atomic, conventional-prefix commit — enforcing the "code + AI_CONTEXT.md together" rule.
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Read
---

Make one clean, atomic commit. (Mid-session sibling of `/handoff`, which also writes the decision log.)

## What changed

- Working tree: !`git status --short`
- Diff summary: !`git diff --stat HEAD`

## Your task

1. Group the changes into **one logical commit**. If the diff spans unrelated concerns, stop and tell the user to split it — don't bundle.
2. **Atomic rule:** if this change reflects a decision, rationale, or next step worth keeping, `AI_CONTEXT.md` must be updated in the *same* commit. If it should be and isn't, say so before committing.
3. Write the message: a conventional prefix (`feat:` / `fix:` / `refactor:` / `docs:` / `chore:`), subject ≤ 72 chars in the imperative, and a body explaining *what* and *why* (not how).
4. Do **not** `git push` (that's `ask`-gated). Report the commit hash and confirm the tree is clean.
