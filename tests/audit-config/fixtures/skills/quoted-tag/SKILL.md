---
name: audit-config-fixture-quoted-tag
description: !!str "Test fixture for scripts/audit-config.sh. Not a real skill; never invoke.
disable-model-invocation: true
end of the tagged, quoted description"
---

A YAML tag before the quote doesn't stop the description from spanning lines, so the
auditor must not claim an opt-out.
