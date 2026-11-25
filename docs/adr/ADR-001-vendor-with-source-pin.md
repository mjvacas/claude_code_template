# ADR-001: Vendor template files with source pins kept by adopters

## Status

Accepted (2026-05-31)

## Context

This template ships files that downstream projects copy into their own
repos: shell scripts (`scripts/check-template.sh`, `scripts/audit-config.sh`),
Claude Code hooks, slash commands, agents, skills, and config. Some encode
security posture that benefits from staying in sync with upstream: the
`block-dangerous.sh` PreToolUse guard, the secret content scan in
`check-template.sh`, and the evasion resistant patterns in `audit-config.sh`.

In practice, the adopter's Claude Code session does the adoption by
reading this repo and copying files into the adopter's project. A human
doesn't run `cp -r`. The session also handles source pinning,
customization, and verification. The template's `docs/ADOPTING.md` owns the
procedure.

Adopters need:

1. A way to know which files travel verbatim vs. get customized.
2. A way to mark which upstream commit a vendored file came from, so
   re-syncing is auditable.
3. A re-sync procedure that doesn't require git plumbing they may not
   have.

Four of the 18 vendor-as-is files are strict JSON with `$schema`
validation (`.claude/settings.json`, `.mcp.json.example`, and the two
`.claude/settings.*.example` files). They can't carry `//` comments, so a
comment header in each file can't be the universal pin mechanism.

A scan of adjacent ecosystems (Go `vendor/modules.txt`, CocoaPods
`.podspec`, Mozilla `moz.yaml`, dotfile communities) found no established
idiom for pinning the source in each file. Vendoring metadata typically
lives in a sidecar file.

## Decision

Adopters maintain a sidecar `VENDORED.md` at the root of their repo,
listing every vendored file with its pinned upstream SHA. The adopter's
Claude Code session creates this file on first adoption and updates it on
each re-sync. **It is the single source of truth** for what's been
vendored and from which commit.

Comment headers in each file (`# Vendored from ... @ <sha>`) remain
optional. Adopters who want extra discoverability when reading a single
file in isolation can opt in for files that support comments. JSON files
skip the optional header without losing pinning, since the sidecar
covers them.

The full procedure (sidecar format, re-sync workflow, paste prompts for
the adopter's CC session) lives in the template's `docs/ADOPTING.md`. This
ADR owns the why.

## Consequences

- One file (`VENDORED.md`) to keep current. Re-sync is a single edit
  rather than N file edits.
- Auditing what's been vendored means reading one file.
- The sidecar works the same across file formats (text, JSON, binary).
- This template stays simple, with no machinery on its side to maintain
  vendoring state.
- Tradeoff: no automation prompts adopters when this template changes.
  They (or their CC session, on a periodic re-sync prompt) check the
  template's `CHANGELOG.md`.

## Alternatives Considered

- **Per file headers as the primary pin.** Self-describing when reading
  a single file in isolation. Rejected because the four strict JSON
  vendor-as-is files can't carry `//` comments, which forces a hybrid
  that's more work than the sidecar alone.
- **Git subtree.** Preserves history, but adopters often don't want this
  template's history in their log. Rebases get messy. Friction outweighs
  benefit for a template most adopters consume partially.
- **Git submodule.** Wrong shape. Vendored files need to live at
  repo root paths (`.claude/`, `scripts/`, `.editorconfig`), not under a
  subdirectory.
- **Fork and diverge (no re-sync).** Viable for low churn adopters but
  means missing security posture updates. Rejected as the default, but
  legitimate as a conscious opt-out.
- **Per file badge in *this* template.** Would add a `# Source: ...`
  header to all 13 vendor-as-is files here. The useful piece (the
  upstream SHA) only exists on the adopter side, so a fixed header here
  would be noise.
