# Changelog

User-visible changes to this template. Adopters consult this when deciding
whether to re-sync vendored files; rationale lives in `docs/adr/`.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Entries are
date-stamped — this template isn't versioned. Convention validated against
`cookiecutter-django` and similar template projects.

## [Unreleased]

### Added
- `docs/ADOPTING.md` — adoption guide: file classification, first-run
  checks, vendoring with source-pin headers, re-sync procedure.
- `docs/adr/ADR-001-vendor-with-source-pin.md` — vendor-with-source-pin
  decision and alternatives.
- `CHANGELOG.md` — this file.

## [2026-05-31]

### Changed
- `templates/AI_SESSION_START.md` footer: portable `sed -i.bak` one-liner
  for the `@templates/` → `@docs/` relocation example. Works on BSD/macOS
  and GNU sed. (#7)

## [2026-05-29]

### Security
- `scripts/check-template.sh` section 6: assert posture invariants
  (deny-list patterns, `.gitignore` lines, regex coverage, `-e` flag, `cut`
  redaction) to defend against silent regressions. (#6)
- `scripts/check-template.sh` section 4: assert mode 600 on 13 local
  secret-bearing file patterns (`.env`, `.env.*`, `.mcp.json`,
  `.claude/settings.local.json`, `*.pem`, `*.key`, `*.p12`, `*.pfx`,
  `*.keystore`, `*_key`, `*_secret`, `id_rsa`, `id_ed25519`). Portable BSD
  + GNU `stat` fallback. (#6)
- `.github/CODEOWNERS` for security-critical paths. Documentary until
  GitHub repo setting "Require review from Code Owners" is enabled. (#6)
- `scripts/check-template.sh`: `shopt -p nullglob` save/restore. (#6)
- `SECURITY.md`: `*.key` fail-closed caveat. (#6)

### Changed
- `templates/AI_SESSION_START.md` rewritten (388 → 105 lines) for the
  hybrid-memory workflow. (#5)

## [2026-05-27]

### Security
- `scripts/check-template.sh`: `-e` flag restored to section-4
  secret-content scan that had silently exit-129'd as "ok" (the
  `-----BEGIN…` literal was being parsed as a `git grep` option). (#4)
- `scripts/check-template.sh`: `cut -d: -f1,2` redaction so a matched
  secret can't leak to CI logs. (#4)
- `scripts/check-template.sh`: `list_files` helper (git-ls-files in a
  repo, pruned-find fallback) so scans don't walk `node_modules`;
  extensionless-basename guard for refs like `@anthropic-ai/sdk`. (#4)
- Deny-list reconciliation across `.claude/settings.json`, `.gitignore`,
  and the `check-template.sh` regex (`*_key`, `*_secret`, `*.pfx`,
  `*.keystore`). (#4)
- `scripts/audit-config.sh` hardened against detection-evasion patterns. (#3)

### Changed
- `SECURITY.md` `Scope` section: customize-me placeholder for adopters. (#4)
