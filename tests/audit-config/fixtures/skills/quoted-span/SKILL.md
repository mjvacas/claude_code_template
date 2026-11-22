---
name: audit-config-fixture-quoted-span
description: "Test fixture for scripts/audit-config.sh. Not a real skill; never invoke.
disable-model-invocation: true
end of the quoted description"
---

The opt-out line sits inside a quoted description that spans lines, so a YAML parser
may read it as text. The auditor can't tell without one, so it must not claim an opt-out.
