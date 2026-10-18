---
name: audit-config-fixture-unclosed
description: Test fixture for scripts/audit-config.sh. Not a real skill; never invoke.
disable-model-invocation: true

The opening fence above is never closed, so Claude Code reads no frontmatter and the
opt-out has no effect. The auditor must list this skill as model-invocable.
