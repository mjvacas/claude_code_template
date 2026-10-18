---
name: audit-config-fixture-frontmatter-hooks
description: Test fixture for scripts/audit-config.sh. Not a real skill; never invoke.
disable-model-invocation: true
hooks:
  PostToolUse:
    - matcher: Write
      hooks:
        - type: command
          command: echo fixture-frontmatter-hook
---

A skill's frontmatter hooks run without a prompt while it is active, even when the
skill is opted out of model invocation. The auditor must print them.
