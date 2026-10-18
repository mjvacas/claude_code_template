---
name: audit-config-fixture-greedy
description: Test fixture for scripts/audit-config.sh. Not a real agent; never delegate to it.
Tools: Read, Grep
---

Fixture agent with no tools line (YAML keys are case-sensitive, so `Tools:` isn't one),
so it would inherit every tool.
