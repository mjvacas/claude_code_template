# Changelog

User-visible changes to this template. Adopters consult this when deciding
whether to re-sync vendored files; rationale lives in `docs/adr/`.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) +
[Semantic Versioning](https://semver.org/). The template is versioned as of
**v0.1.0** (beta) — see
[ADR-006](docs/adr/ADR-006-versioning-and-release-management.md) for what
MAJOR/MINOR/PATCH mean for a vendored template and why we start in beta.
Pre-0.1.0 history is kept below in the original date-stamped sections.

## [Unreleased]

## [0.2.2] - 2026-06-27

### Changed
- **README** — Quick-start clone now pins the release tag; plain-language pass on
  the intro; linked the three-bucket `CLAUDE.md` merge scheme. (#40, #41)
- **`docs/ADOPTING.md`** — genericized the version examples. (#40)
- **README** — added a footer linking the project page on
  [ventureforward.ai](https://ventureforward.ai/projects/claude-code-template/).

## [0.2.1] - 2026-06-23

### Fixed
- **Fresh adoption now passes `check-template.sh`** — `docs/summaries/.gitkeep`
  was missing from the `docs/ADOPTING.md` file map, so a by-the-book new-repo
  adoption failed §5 (`missing directory: docs/summaries`) on the very
  verification step the procedure says to run. Added it to the **Vendor as-is**
  list. (Surfaced by an end-to-end clone→adopt→uninstall dry run.)
- **`check-template.sh` no longer silently under-checks before staging** —
  `list_files()` now unions tracked with untracked-but-unignored files, so the
  integrity checks (§1 JSON validity, §3 `@`-reference resolution) cover
  just-vendored files even before `git add`. Previously a fresh, unstaged
  adoption made `git ls-files` return nothing and §1/§3 passed as no-ops. The
  ADOPTING procedures + **Verification** section now say to **stage first** so
  the §4 secret-content scan (tracked-only by design) also covers the adoption.
- **CODEOWNERS adopter guidance** — the file ships with the maintainer handle
  (`@mjvacas`), not a `@<owner>` placeholder; `docs/ADOPTING.md` and an in-file
  comment now tell adopters to replace it, so they don't silently leave the
  maintainer as code-owner of their own security-critical files.
- **CLAUDE.md three-bucket merge** — the "keep verbatim" sections carry prose
  pointers to reference-only docs (`docs/skill-security.md`,
  `docs/token-awareness.md`, `docs/claude-code-setup.md`); the merge guidance now
  says to repoint them upstream or drop them so they don't dangle.
- **Uninstall back-out** — note that a full removal deletes `check-template.sh`
  itself (run it *before* the final delete), and that a manifest-driven delete
  leaves empty parent dirs + an orphaned `docs/summaries/` to sweep.

## [0.2.0] - 2026-06-17

### Added
- **Uninstall / back-out procedure** — `docs/ADOPTING.md` gains an
  **Uninstalling / backing out** section: `git revert` the atomic adoption
  commit (undoes vendored files **and** the `CLAUDE.md` / `.gitignore` /
  `settings.json` merges in one move), then clean up the out-of-repo pieces
  (`claude plugin uninstall` per `VENDORED.md` → `## Installed plugins`, plus
  `.mcp.json` entries), with the three half-removal traps called out. Closes the
  adopt / re-sync / **undo** completeness gap.

### Changed
- **Statusline: session context vs. budget** — `.claude/statusline.sh` now
  renders session context as **absolute tokens against the window** (`ctx
  152k/1M`) with a `⚠` nudge at the fixed **~200k** mark, independent of window
  size — so a 1M-context model warns where a raw fill % would not trip 80% until
  800k. Adds the **weekly (`seven_day`) rate-limit window** (`7d`) beside the
  existing 5-hour one (`rate_limits.seven_day.used_percentage`, subscription
  plans; each window may be independently absent), each shown with its **reset
  clock** (`5h 24% (16:30)` / `7d 41% (Tue 16:30)`, from
  `rate_limits.*.resets_at`). Falls back to a context **%**
  when `context_window_size` is absent, preserving prior behavior on older
  Claude Code versions. `docs/token-awareness.md` gains a **Session context vs.
  budget** section: context is resettable (`/clear` · `/handoff`), budget is
  cumulative — clearing context cuts *future* burn, not *past* spend.
- **Re-sync procedure hardening** — `docs/ADOPTING.md` consolidates the re-sync
  guidance from the 5-adopter sweep: a `VENDORED.md` deviation ledger,
  re-applying path-repoints on each re-sync (don't blind-copy over adaptations),
  ADR-number-collision handling, and co-required-add detection — making large
  multi-PR re-syncs safer.

### Security
- **CI: pin `actions/checkout` to a commit SHA** — `.github/workflows/check.yml`
  now pins `actions/checkout` to `34e1148…` (`v4.3.1`) instead of the mutable
  `@v4` tag, matching the SHA-pinning posture `docs/skill-security.md` teaches
  adopters. Closes the gap where the template violated its own supply-chain rule.

## [0.1.0] - 2026-06-13

_First versioned release — **beta** (`v0.1.0`). SemVer per
[ADR-006](docs/adr/ADR-006-versioning-and-release-management.md); the go-public
commit is tagged `v0.1.0`. Entries below were previously under `[Unreleased]`._

### Added
- **Versioning & release management** — the template is now versioned with
  SemVer, starting at **v0.1.0 (beta)**, replacing the date-stamped
  "unversioned" convention. MAJOR/MINOR/PATCH are defined against the
  *adoption contract*; adopters pin `VENDORED.md` to a release tag (the SHA
  stays the exact anchor) so re-sync can answer "am I behind / is it
  breaking?". Rationale and the path to v1.0.0 in
  [ADR-006](docs/adr/ADR-006-versioning-and-release-management.md).
- **Token awareness (legibility layer)** — new `docs/token-awareness.md`
  hub makes already-known token costs legible at the decision point
  (adopting a plugin, wiring a feature, choosing a model), motivated by
  higher-consumption models like Fable. Three parts: a **cost-class
  taxonomy** (`free-local` / `on-use` / `session` / `per-prompt`) defined
  once and mapped onto the plugin catalog's two cost axes
  (`tokens.*.always_on` / `on_invoke`) so both speak one vocabulary; a
  **per-session cost ledger** that itemizes the always-on context tax but
  defers the *numbers* to Claude Code's native `/context` and `/usage`
  (which can break cost down per component depending on plan) rather than
  freezing figures that rot; and a tier-based
  **model-routing heuristic**, explicitly provisional, to be superseded
  by `cc-task-bench` V2 measured data. Thin pointers, no duplication: a
  **`Cost` column** on the `.claude/` table in `docs/claude-code-setup.md`,
  a vetting-checklist line in `docs/skill-security.md`, cross-links from
  `CONTRIBUTING.md`'s opt-in principle and `docs/ADOPTING.md` (plugin
  discovery + a "Reference only" file-map row), a `CLAUDE.md` Context-
  System pointer, and a `README.md` layout row. The guiding rule —
  *a stale cost number is worse than none* — keeps the design on cost
  *classes* and live native tools; the one anchored figure (~9k tokens
  for a maxed `AI_CONTEXT.md`) stays owned by ADR-004 and is linked, not
  restated. Empirical **measurement** (the `cc-task-bench` V2 runner)
  stays in the backlog.
- **Statusline live cost/context signals** — `.claude/statusline.sh` now
  renders, when the status event carries them, the live **context-window
  fill %** (`context_window.used_percentage`), **5-hour rate-limit usage**
  (`rate_limits.five_hour.used_percentage`, subscription plans), and an
  **estimated session cost** (`cost.total_cost_usd`, shown as `~$`), each with
  a ⚠ marker at ≥80%. The cost is **plan-aware**: on subscription plans the
  dollar figure is notional (flat subscription, not per-token billing), so it
  reads as a charge and is **hidden** — the 5h limit is the real constraint
  there; `~$` shows only on pay-as-you-go events (no `rate_limits`), where it's
  a real cost. The context % replaces the old binary `>200k` warning as the
  primary signal (falling back to it only when the % is absent), which fixes
  over-warning on 1M-context models where `exceeds_200k_tokens` fires at ~20%.
  All fields are read defensively and omitted when missing. This is a
  `free-local` signal — the status line never enters the model's context, so it
  costs zero tokens and ships wired (unlike the per-prompt clock heartbeat).
- **`docs/adr/ADR-005-token-awareness-legibility.md`** — records the
  decision to ship token awareness as a *legibility* layer now (cost
  classes + native `/context`/`/usage`) while *measurement* stays deferred
  to `cc-task-bench` V2. Reconciles the apparent tension with ADR-003's
  measurement-first stance (a labeled heuristic is not a measured claim and
  carries a clean supersession target) and cites ADR-004 for the
  `AI_CONTEXT.md` token figure it inventories.
- **`CONTRIBUTING.md`** — the contributor-facing sibling of
  `docs/ADOPTING.md` (fixes flowing *in* vs the template flowing *out*),
  previously referenced there as "(future)". Covers workflow (one concern
  per PR, conventional commits, review-before-commit, no-amend-after-push,
  stacked-branch rebase rule, secretless-CI constraint) and — new —
  **repo-specific working agreements** that were previously encoded
  nowhere in-repo: no `/handoff` here (`AI_CONTEXT.md` stays blank for
  adopters), no named adopters in public docs, verify adopter-feedback
  premises before shipping, recurring-token-cost features default to
  opt-in. Closes with a "promote practices out of auto-memory" routine —
  the structural fix for practices accumulating in machine-local memory
  that doesn't travel (how an adopter ended up with the review plugin
  installed but no reviews running). README layout + ADOPTING.md
  reference-only file-map row added.
- **Session clock** — sessions have no inherent sense of time (the date
  injected at session start goes stale across midnight/compaction, and
  the model can't notice elapsed time on its own). Three pieces, two of
  them always-on and free: the `SessionStart` hook now prints a
  "Session started:" timestamp line (and is no longer a full no-op
  outside git — the clock line still prints); `/handoff` and `/adr`
  inject today's date at invocation instead of trusting context (new
  `Bash(date:*)` in their allowed-tools). The third piece is opt-in:
  `.claude/hooks/clock.sh`, a `UserPromptSubmit` heartbeat that injects
  the current time on every prompt (elapsed session time = subtract the
  session-start line) — ships **unwired** because it costs a few tokens
  per prompt; enable via the snippet in `docs/claude-code-setup.md`
  § Optional: session clock heartbeat.
- **`docs/adr/ADR-004-ai-context-archive-threshold-bump.md`** — supersedes
  ADR-002 (which stays in-repo as the original research-anchored historical
  record). Records the 500 → 750 line `AI_CONTEXT.md` archive threshold bump
  and the new `/handoff` state-sufficiency requirement that makes the higher
  cap safe.
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
- **Three new file-map rows in `docs/ADOPTING.md` § File map (Vendor
  as-is)**: `.github/workflows/check.yml` (the CI workflow running
  `check-template.sh` + gitleaks on every PR/push — without it the
  template's security posture isn't enforceable on the adopter's
  PRs), `docs/adr/ADR-001-vendor-with-source-pin.md`, and
  `docs/adr/ADR-002-ai-context-archive-threshold.md`. All three were
  referenced in procedure prose but missing from the file-map table
  that adopters/sessions actually consult. ADRs carry the
  sub-namespacing caveat from the existing § First-time adoption
  callout (adopters with their own `docs/adr/` series should sub-
  namespace to avoid numbering collision).
- **`## Merging the template's CLAUDE.md`** — new top-level section
  in `docs/ADOPTING.md` between § First-time adoption and § Source-
  pin manifest. `CLAUDE.md` is structurally a hybrid (some sections
  are template-shared engineering principles + load-bearing framework
  prose, others are pure project scaffold); the previous file-map
  classification ("skeleton, fill placeholders") didn't distinguish.
  Adopters following the procedure literally dropped the template-
  shared content (Conventions block, Context System, four-principle
  behavioral guidelines), silently breaking the contract the rest of
  the template assumes. The new section gives a three-bucket
  categorization: keep-verbatim, keep-framing-replace-content, and
  pure-scaffold-replace. Existing-repo procedure step 3 now points
  at this section instead of asking for a generic "specific merge."
- **Inline rationale comment above `secrets/` in `.gitignore`**:
  one-liner noting the catch-all-credential-folder convention
  (Helm sealed-secrets, Terraform/K8s vault, Ansible vault). Origin
  was previously implicit (added in the 2026-05-23 "secrets
  hardening" commit `4c8c5ca` alongside `.env*` / keys / etc., with
  no in-codebase explanation); future readers re-examining the line
  now have the rationale inline.
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
- **Re-sync now treats `VENDORED.md` as the adopter's deviation ledger**
  (`docs/ADOPTING.md`), from a read-only sweep of five downstream adopters.
  Each had relocated/repointed/skipped differently, and the procedure
  blind-copied over those choices. Now: the schema gains a
  **`## Deliberately not vendored`** section and the add-check skips anything
  recorded there (so reference-only/template-internal files aren't re-proposed
  every sync); **Update/Merge re-applies a file's recorded `@templates/` repoint**
  instead of blind-copying (e.g. `adr.md`), with a `grep '@templates/'` gate
  before commit; the add-check treats a file a *changed* command now references
  (e.g. `handoff.md` → ADR-004) as a **co-required add**, and **sub-namespaces
  an incoming ADR whose number collides** with the adopter's own series. The
  file map classifies the template-internal **ADR-003/005/006** (Reference only)
  and flags that `adr.md` carries an `@templates/` ref.
- **`scripts/check-template.sh` § 3b removed — redundant with § 3.** § 3 already
  resolves *every* `@`-ref in tracked `.md` files (source and adopter alike), so
  it catches a dangling `@templates/` ref (relocated/stripped without repointing)
  on its own. § 3b only re-implemented a subset and carried a footgun — its
  source-repo skip keyed on `docs/ADOPTING.md` presence, so an adopter who
  vendored that file would silently disable the check. Removing § 3b deletes the
  redundancy and the footgun; § 3b references in `docs/ADOPTING.md` and the CI
  workflow comment repoint to § 3.
- **Re-sync procedure hardened for large multi-PR jumps** (`docs/ADOPTING.md`
  § Re-syncing), from a downstream dogfooding pilot. The steady-state procedure
  only *updated* already-vendored files; it now also **adds** newly-vendored
  files an adopter never picked up (e.g. `.github/workflows/check.yml`),
  **deletes** files removed upstream and surfaces their replacements (e.g. an
  agent superseded by a baseline plugin), routes a changed `CLAUDE.md` through
  the bucket-1 merge guide instead of a blind diff, backfills `VENDORED.md`
  sections missing from older pins, and reads pre-`v0.1.0` date-stamped history
  for deletions/additions that don't show as a SemVer bump. Tag-based pins
  degrade gracefully to SHA before the first tag is cut.
- **Public-readiness doc cleanups** — `SECURITY.md` drops the unfilled email
  placeholder in favor of GitHub private vulnerability reporting; the
  `docs/ADOPTING.md` file map adds the `cc-task-bench` skill (reference-only)
  and `bench/` (skip) and drops the removed `old/` directory.
- **Two workflow practices promoted from machine-local auto-memory into
  the template** (`CLAUDE.md` `## Conventions` + `/commit` step 3), after
  an adopter repo was observed not running PR review despite having the
  plugin installed: (1) *review-before-commit* — run the review plugin's
  `code-reviewer` agent on non-trivial diffs before committing; agents
  are model-invoked and never fire on their own, so installing
  `pr-review-toolkit` without this convention silently yields zero
  reviews; (2) *no-amend-after-push* — add a fixup commit instead;
  the PreToolUse hook already hard-blocks force-push, but stating the
  practice saves sessions from learning it at hook-block time. Both are
  Bucket-1 (keep-verbatim) content, so they reach adopters on merge;
  `docs/ADOPTING.md`'s bucket-table enumeration updated to name them.
- **`CLAUDE.md` skeleton de-opinionated** to match `docs/ADOPTING.md`'s
  "language-agnostic — no framework lock-in" claim. The scaffold sections
  (`## Tech Stack`, `## Project Structure`, `## Key Files`, `## Commands`)
  previously defaulted to a React Native/TypeScript/npm stack; they now use
  role-based placeholders with ecosystem-diverse examples (JS, Python, Go).
  The `## Conventions` block — keep-verbatim on merge per the three-bucket
  scheme, so its old React phrasing ("keep screens thin — push logic into
  hooks") traveled into every adopter's repo — is de-flavored: entry-points-
  thin replaces screens-thin, types-first drops the `types/` directory
  assumption, defensive-defaults shows JS and Python fallback idioms.
  Principle names (don't-duplicate, types-first,
  defensive-defaults-at-boundaries, …) are unchanged, so the bucket
  enumeration in `docs/ADOPTING.md` and the cross-references in
  `templates/ARCHITECTURE.md` still resolve. Section headings are
  unchanged, so the three-bucket merge tables need no edits. Also
  de-flavors one AI-Integration-Patterns bullet ("across screens" →
  "across call sites").
- **`AI_CONTEXT.md` archive threshold: 500 → 750 lines.** Origin: 500 was
  being hit after a single long session, generating archival friction
  (SessionStart nag, mid-flow `/handoff` interruption) that outweighed the
  lost-in-the-middle retrieval cost it was guarding against. 750 keeps most
  of ADR-002's retrieval headroom intact (~9k tokens vs the 10k attention-safe
  envelope); 1000 was considered and rejected as sacrificing too much.
- **`/handoff` state-sufficiency requirement** (new in step 1): each session
  block must carry enough Current State / Decisions / Open Questions / Next
  Steps for a cold-start `/session-start` to resume from the latest block
  alone, without reading archived summaries. Archival is safe at the higher
  cap because of this discipline (step 3 cites step 1 as the safety basis).
- **Threshold-value cascade** propagated to `.claude/hooks/session-context.sh`,
  `.claude/commands/handoff.md`, `AI_CONTEXT.md` header,
  `templates/AI_SESSION_START.md`, and the CLAUDE.md ADR highlight (now lists
  both ADRs with ADR-002 flagged superseded). `docs/ADOPTING.md` § First-time
  adoption callout and § File map updated to mention ADR-004 and flag ADR-002
  superseded so adopters vendor the right files with the right framing.
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
- **`scripts/check-template.sh` § 3b is now a resolution check, not a substring
  grep** (from a downstream dogfooding pilot). It previously failed on *any*
  `@templates/...` occurrence in `.claude/commands` / `.claude/skills`, which
  contradicted `docs/ADOPTING.md`'s "repoint *if* you relocated or stripped
  `templates/`" framing: an adopter who vendored `templates/` verbatim (refs
  still resolve) passed § 3 but failed § 3b, making relocation effectively
  mandatory. § 3b now fails only on refs whose **target file is missing**, so a
  verbatim-vendored `templates/` passes. Also fixed the now-stale "do this step
  even if `templates/` was kept" wording in both first-time procedures, and
  changed the relocation example (here and in `templates/AI_SESSION_START.md`)
  to recommend a **namespaced subdir** (`docs/claude-code-template/`) instead of
  a flat `docs/`, which collided with the CLAUDE.md-reserved
  `docs/{PROJECT_SPEC,ARCHITECTURE,BUILD_PLAN}.md` triad.
- **`scripts/check-template.sh` § 3b source-repo detection** rewritten
  from env-var gating (`CHECK_TEMPLATE_SOURCE`) to auto-detection by
  `docs/ADOPTING.md` presence (template-internal; adopters read it from
  the template clone and never vendor it). The env-var design failed in
  both directions: the documented local run
  (`bash scripts/check-template.sh`) failed in the source repo on its
  own correct `@templates/` refs, and the vendored-as-is
  `.github/workflows/check.yml` hardcoded the variable — so adopter CI
  never ran the adopter-side check it was built for. The variable is
  removed from both the script and the workflow.
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

[unreleased]: https://github.com/mjvacas/claude_code_template/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/mjvacas/claude_code_template/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/mjvacas/claude_code_template/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/mjvacas/claude_code_template/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/mjvacas/claude_code_template/releases/tag/v0.1.0
