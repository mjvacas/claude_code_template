# ADR-001: Vendor template files with adopter-side source pins

## Status

Accepted (2026-05-31)

## Context

This template ships files that downstream projects copy into their own
repos: shell scripts (`scripts/check-template.sh`, `scripts/audit-config.sh`),
Claude Code hooks, slash commands, agents, skills, and config. Some encode
security posture that benefits from staying in sync with upstream — the
`block-dangerous.sh` PreToolUse guard, the secret-content scan in
`check-template.sh`, the evasion-resistant patterns in `audit-config.sh`.

In practice, adoption is driven by the adopter's Claude Code session
reading this repo and copying files into the adopter's project — not by
a human running `cp -r`. The session also handles source-pinning,
customization, and verification. `docs/ADOPTING.md` owns the procedure.

Adopters need:

1. A way to know which files travel verbatim vs. get customized.
2. A way to mark which upstream commit a vendored file came from, so
   re-syncing is auditable.
3. A re-sync procedure that doesn't require git plumbing they may not
   have.

Four of the 18 vendor-as-is files are strict JSON with `$schema`
validation (`.claude/settings.json`, `.mcp.json.example`, and the two
`.claude/settings.*.example` files). They can't carry `//` comments, so a
per-file comment header can't be the universal pin mechanism.

A scan of adjacent ecosystems (Go `vendor/modules.txt`, CocoaPods
`.podspec`, Mozilla `moz.yaml`, dotfile communities) found no established
per-file source-pin idiom — vendoring metadata typically lives in a
sidecar file.

## Decision

Adopters maintain a sidecar `VENDORED.md` at the root of their repo,
listing every vendored file with its pinned upstream SHA. The adopter's
Claude Code session creates this file on first adoption and updates it on
each re-sync. **It is the single source of truth** for what's been
vendored and from which commit.

Per-file `# Vendored from ... @ <sha>` comment headers remain optional —
adopters who want extra discoverability when reading a single file in
isolation can opt in for files that support comments. JSON files skip the
optional header without losing pinning; the sidecar covers them.

The full procedure — sidecar format, re-sync workflow, paste-prompts for
the adopter's CC session — lives in `docs/ADOPTING.md`. This ADR owns
the why.

## Consequences

- One file (`VENDORED.md`) to keep current; re-sync is a single edit
  rather than N file edits.
- Auditing what's been vendored is a one-file read.
- The sidecar works uniformly across file formats — text, JSON, binary.
- This template stays simple; no machinery on its side to maintain
  vendoring state.
- Trade-off: no automation prompts adopters when this template changes.
  They (or their CC session, on a periodic re-sync prompt) check
  `CHANGELOG.md`.

## Alternatives Considered

- **Per-file headers as the primary pin** — self-describing when reading
  a single file in isolation. Rejected because the four strict-JSON
  vendor-as-is files can't carry `//` comments, forcing a hybrid that's
  more work than sidecar-alone.
- **Git subtree** — preserves history, but adopters often don't want this
  template's history in their log; rebases get messy. Friction outweighs
  benefit for a template most adopters consume partially.
- **Git submodule** — wrong shape. Vendored files need to live at
  repo-root paths (`.claude/`, `scripts/`, `.editorconfig`), not under a
  subdirectory.
- **Fork-and-diverge (no re-sync)** — viable for low-churn adopters but
  means missing security-posture updates. Rejected as the default;
  legitimate as a conscious opt-out.
- **Per-file badge in *this* template** — would add a `# Source: ...`
  header to all 13 vendor-as-is files here. The useful piece (the
  upstream SHA) only exists on the adopter side; a fixed header here
  would be noise.
