# Changelog

User-visible changes to this template. Adopters consult this when deciding
whether to re-sync vendored files; rationale lives in `docs/adr/`.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Entries are
date-stamped — this template isn't versioned. Convention validated against
`cookiecutter-django` and similar template projects.

## [Unreleased]

### Added
- **Plugin activation caveat** in `docs/ADOPTING.md` § Plugins:
  documents the silent-failure trap where newly-installed plugins don't
  bind to the active session until `/reload-plugins` (slash command) or
  session restart. New-repo, existing-repo, and re-sync procedures now
  explicitly prompt for `/reload-plugins` after install steps, so the
  just-installed plugins actually review the adoption/re-sync commit.
  Without this, adopters following the procedures literally would ship
  unreviewed commits while believing the plugins ran.
- **MCP server discovery** as a sibling to plugin discovery in
  `docs/ADOPTING.md` § Plugins: covers standalone MCP servers from the
  broader ecosystem (e.g. `modelcontextprotocol/servers`) that the
  Claude Code marketplaces don't index. Selected MCP servers install
  into `.mcp.json`, separate from `VENDORED.md`'s plugin section
  (different distribution model). Renamed `### Discovery` →
  `### Plugin discovery` with new sibling `### MCP server discovery`;
  vetting rubric heading updated to cover both.
- **Plan-mode recommendation** at the top of `docs/ADOPTING.md`
  § First-time adoption: both procedures (new-repo and existing-repo)
  have a natural read-and-decide phase before any writes — plugin
  enumeration, secret-file mode checks, merge planning. Plan mode
  lets the session surface all of that as a reviewable plan before
  touching files, avoiding mid-flow surprises. Especially valuable
  for the existing-repo procedure. Links to Anthropic's canonical
  plan-mode documentation.
- **ADR sub-namespacing callout** in `docs/ADOPTING.md`
  § First-time adoption: adopters with their own `docs/adr/` series
  collide with the template's `ADR-001` and `ADR-002` if they vendor
  naïvely. New callout points at `docs/claude-code-template/` and
  `docs/adr/_upstream/` as common sub-namespaces, with a reminder
  to repoint inline cross-doc references.
- **Per-file `@templates/...` inventory table** in both first-time
  procedures' Repoint step: lists the four surviving refs across
  three `.claude/commands/` files (down from seven after the skills
  cleanup below). Also adds a callout for prose-level
  `docs/skill-security.md` / `docs/adr/ADR-NNN-*.md` references in
  vendored skeleton templates (not `@`-imports, so
  `scripts/check-template.sh` doesn't catch them).

### Changed
- New-repo procedure step 7 now mirrors existing-repo step 6's
  `claude plugin list` precheck pattern: check first, default-install
  only what's missing, confirm-enabled for what's already there. Avoids
  re-prompting power-user adopters about baseline plugins they already
  have at user scope from prior adoptions.
- New-repo step 8, existing-repo step 7, and re-sync step 5 renamed
  from "plugin discovery" to "plugin + MCP discovery" to reflect the
  expanded scope.
- Genericized adopter credits in `README.md` Acknowledgements and the
  `CHANGELOG.md` PR #9 entry: replaced the specific downstream-project
  bullet with "Personal projects dogfooding the template." Preserves
  the battle-tested claim without naming specific adopters in
  public-facing docs.
- **`/reload-plugins` prompts consolidated** in both first-time
  procedures: previously prompted in two adjacent steps (baseline
  install + plugin/MCP discovery); now prompted once after both
  install phases complete. Cleaner execution; same activation
  guarantee.
- **`scripts/check-template.sh` § 1 skips JSONC files**
  (`tsconfig.json`, `tsconfig.*.json`, `.vscode/*.json`) which legally
  carry `/* */` and `//` comments. Strict `json.load` was failing
  these and blocking adoption for any project that ships them (e.g.
  Vite + TS frontends).

### Removed
- **`templates/LLM_APP_DEVELOPMENT_BEST_PRACTICES.md`** (826 lines):
  duplicated content from `CLAUDE.md` § Context System and
  `templates/AI_SESSION_START.md`, plus carried stale `50KB` and
  `docs/archive/*.gz` references already removed elsewhere in the
  2026-05-27 hybrid-memory rewrite (commit `50bbd6c`). The Testing
  & Validation patterns the three skills (`llm-eval`,
  `tune-parameters`, `verify-refactor`) used to `@`-ref now live
  inline in each `SKILL.md` — closer to the mechanics they
  describe, with no risk of doc/code drift. Cleanup also touched
  `README.md` Layout, `docs/ADOPTING.md` file map, and
  `docs/claude-code-setup.md` § "Where the long-form guidance lives".
- Historical `old/` directory and its two files (`AI_SESSION_START.md`,
  `LLM_APP_DEVELOPMENT_BEST_PRACTICES.md`) — the project-specific
  predecessors that were abstracted into `templates/` during the
  initial template extraction. No longer relevant for adopters;
  retrievable from `git log` for anyone tracing the abstraction lineage.
  Also drops the matching `except old/` callout in `README.md` Quick
  start step 1 and the `old/` line in the Layout block.

### Fixed
- **Plugin vetting reframed from marketplace-based to authorship-based**
  in `docs/ADOPTING.md`. The previous wording assumed
  "Anthropic-official marketplace ⇒ Anthropic-authored ⇒ trusted, skip
  vetting." That's wrong: `claude-plugins-official` is a *curation*
  surface. Of the 222 plugins listed there at the time of writing,
  only 50 are Anthropic-authored; the other 172 are vendor-maintained
  (RevenueCat, Sentry, Supabase, Semgrep, AWS, etc.) and were silently
  being skipped from the vetting rubric. The discriminator is now
  the schema of `marketplace_entry.source`: a **string** path
  (`"./plugins/<name>"`) means Anthropic-authored and trusted by
  default; an **object** with a `url` or `repo` means third-party-
  authored and runs the full license + maintainer + recency rubric,
  regardless of which marketplace lists it. The
  `### Vetting rubric` heading is renamed from "community plugins and
  MCP servers" to "third-party-authored plugins and MCP servers" to
  match the corrected scope; existing anchor link from
  `### Plugin discovery` updated accordingly. Baseline-plugins paragraph
  also tightened (`Anthropic-official` ⇒ `Anthropic-authored`).

## [2026-06-06]

### Added
- **Baseline plugins** concept: two Anthropic-official plugins
  (`security-guidance@claude-plugins-official`,
  `pr-review-toolkit@claude-plugins-official`) default-installed during
  adoption with per-plugin opt-out. Documented in
  `docs/ADOPTING.md` § Plugins. (#10)
- **Plugin discovery** step in new-repo, existing-repo, and re-sync
  procedures: AI session searches `claude-plugins-official` and
  `claude-community` (if added) for project-relevant plugins, surfaces
  candidates with vetting info, user picks. (#10)
- **Vetting rubric** for community plugins (explicit license + named
  maintainer + commit within ~6 months + explicit user approval). (#10)
- `Installed plugins` subsection in the `VENDORED.md` schema. (#10)
- `README.md`: Acknowledgements section (Anthropic Claude Code,
  multica-ai/andrej-karpathy-skills, Keep a Changelog, ADR concept by
  Michael Nygard, real-world feedback from personal projects
  dogfooding the template). (#9)
- `README.md`: Related templates section noting
  `scotthavird/claude-code-template` and `davila7/claude-code-templates`
  as reviewed-for-comparison prior art. (#9)

### Removed
- `.claude/agents/code-reviewer.md` — superseded by
  `pr-review-toolkit@claude-plugins-official` (now a baseline plugin
  installed during adoption). Existing adopters: see ADOPTING.md
  re-sync section for the swap. (#10)
- References to the dropped agent in `README.md`, `CLAUDE.md`, and
  `docs/claude-code-setup.md` updated accordingly. (#10)

### Security
- Template's own security-relevant code verified against
  `security-guidance@claude-plugins-official` v2.0.3 during PR #10.
  Layer-1 regex patterns target web-vuln classes in
  Python/JS/TS/Go/YAML and don't natively apply to our bash/JSON/markdown
  security code (already hardened in PRs #3–#6). The one in-scope file,
  `.github/workflows/check.yml`, was manually audited against the
  plugin's GHA-workflow rule: no findings (no untrusted-input
  interpolation; least-priv `permissions: contents: read`; no
  `pull_request_target`; sha256-verified binary download). Layers 2–3
  (LLM diff review + agentic commit review) bound to PR #10's commit on
  `/reload-plugins`; no findings surfaced (docs-only diff has no
  reviewable source files per the agentic reviewer). (#10)

## [2026-05-31]

### Added
- `docs/ADOPTING.md` — adoption guide: file classification, first-run
  checks, vendoring with source-pin sidecar (`VENDORED.md`), new-repo /
  existing-repo / re-sync procedures driven by the adopter's CC session. (#8)
- `docs/adr/ADR-001-vendor-with-source-pin.md` — sidecar-manifest
  decision and alternatives considered. (#8)
- `CHANGELOG.md` — this file. (#8)

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
