---
name: audit-config-fixture-midline-fence
description: Test fixture for scripts/audit-config.sh. Splits notes on --- markers; never invoke.
disable-model-invocation: true
---

Claude Code's frontmatter ends at the first `---`, even mid-line, so the opt-out above
falls outside it. The auditor must list this skill as model-invocable.
