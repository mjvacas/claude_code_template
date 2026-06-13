# Adopting this template

> **Audience.** You (or me — the maintainer is also the primary adopter)
> sitting in a *different* repo with a Claude Code session open. Adoption
> is driven by that session, not by manual `cp -r`. This doc tells the
> session what to do.
>
> If you're sending a fix *back* to this repo, see
> [`CONTRIBUTING.md`](../CONTRIBUTING.md) — different doc, different audience.

## What this template is

A personal Claude Code starter: security posture (deny-list, dangerous-
command hook, secret-content scan, vetting scripts), session workflow
(`/session-start`, `/handoff`, `/commit`, `/adr`), and a hybrid memory
model (`CLAUDE.md` + `AI_CONTEXT.md` + native auto-memory + ADRs).
Language-agnostic — no build tooling, no test runner, no framework
lock-in.

Adopting doesn't have to be all-or-nothing. The file map classifies each
file by how it's meant to travel.

## Plugins

Two kinds: **baseline** (installed by default during adoption) and
**discovered** (project-specific, enumerated from the local marketplace
manifest during adoption — no freeform "search").

### Baseline plugins

Universally useful regardless of project. The adopter's CC session
installs them by default at user scope; the user opts out per plugin if
not wanted. Both are Anthropic-authored (string `source` field — see
the authorship discriminator under [Plugin discovery](#plugin-discovery)),
so the third-party vetting rubric below doesn't apply.

- **`security-guidance@claude-plugins-official`** — reactive SAST and
  diff-review. Complements this template's *preventive* posture (deny-list,
  `block-dangerous.sh` PreToolUse guard) by catching vulnerabilities in
  the code Claude *writes*, not just the commands it tries to *run*.
- **`pr-review-toolkit@claude-plugins-official`** — specialized PR review
  agents (`silent-failure-hunter`, `type-design-analyzer`,
  `pr-test-analyzer`, `comment-analyzer`, `code-simplifier`,
  `code-reviewer`). Replaces the `code-reviewer` agent this template
  previously shipped; richer specialization, maintained upstream.

### Plugin discovery

For project-specific plugins beyond the baseline, the session matches
the user's tech stack + domain + working style against the
**authoritative plugin catalog** — not a freeform "search." There is
**no `claude plugin search` subcommand**; the failure mode this
procedure prevents is the session confabulating plausible-sounding
plugin names (`expo@claude-plugins-official` and similar) that don't
exist in any marketplace.

**Enumeration (the session runs these in order):**

1. Refresh marketplaces so the local catalog matches upstream:
   ```bash
   claude plugin marketplace update
   ```
2. Enumerate the authoritative catalog. One JSON file covers all
   configured marketplaces and carries description, author, version,
   source SHA, last commit, component inventory, and per-model token
   costs:
   ```bash
   # List of every available plugin (as <name>@<marketplace> keys):
   jq -r '.catalog.plugins | keys[]' ~/.claude/plugins/plugin-catalog-cache.json

   # Full metadata for a specific candidate:
   jq '.catalog.plugins."<name>@<marketplace>"' \
     ~/.claude/plugins/plugin-catalog-cache.json
   ```
3. Match against the user's stack **using only names that appear in
   step 2's output.** A name not in the catalog does not exist;
   propose it and the install will fail with "not found." Confabulation
   is rejected by construction.

For each verified candidate, surface (all readable from the catalog
entry — no guessing):

- **Name + marketplace + description** (`marketplace_entry.description`)
- **Components** — skills / agents / hooks / MCP / LSP servers
  (`components.{commands,agents,skills,hooks,mcpServers,lspServers}`)
- **Maintainer + last commit** (`marketplace_entry.author.name`,
  `last_updated`)
- **Per-session token cost** (`tokens.<model>.always_on` and
  `tokens.<model>.on_invoke` — the `session` / `on-use` cost classes in
  [`docs/token-awareness.md`](token-awareness.md))
- **How it relates to this template** (orthogonal / complementary /
  overlapping)

**License** is not in the catalog. The trust model is
**authorship-based, not marketplace-based** — being listed in
`claude-plugins-official` is curation, not authorship. The discriminator
is one field:

```jq
.marketplace_entry.source | type == "string"   # ⇒ Anthropic-authored
```

A **string** source (e.g., `"./plugins/security-guidance"`) is a path
within the `anthropics/claude-plugins-official` repo itself —
Anthropic-authored, trusted by default. An **object** source
(`{ "url": "https://github.com/<vendor>/<repo>.git", ... }`, or
`{ "repo": "<vendor>/<repo>", ... }` for the `github` sub-schema) points
to a vendor-maintained repo — third-party-authored, **needs the full
vetting rubric regardless of which marketplace lists it.** Of the 222
plugins in `claude-plugins-official` at the time of writing, only 50 are
Anthropic-authored; the other 172 are third-party-curated.

For each third-party-authored candidate, fetch the license from the
source repo (`marketplace_entry.source.url` when present; otherwise
construct from `marketplace_entry.source.repo`) and confirm a declared
license before installing — see
[Vetting rubric](#vetting-rubric-third-party-authored-plugins-and-mcp-servers).

User picks. Session installs (`claude plugin install <name>@<marketplace>`)
and records selections in `VENDORED.md` under "Installed plugins".

> **Adopting `claude-community`.** Only configured marketplaces are
> enumerable. To consider plugins from `claude-community`, the user
> runs `claude plugin marketplace add anthropics/claude-community`
> before step 1; otherwise step 2 surfaces only `claude-plugins-official`
> entries. All `claude-community` plugins are third-party-authored
> by construction, so every candidate runs the full vetting rubric.

### MCP server discovery

The Claude Code plugin marketplaces aren't the only source of useful
extensions. The broader MCP ecosystem (canonical index:
[`modelcontextprotocol/servers`](https://github.com/modelcontextprotocol/servers))
hosts standalone MCP servers (Postgres, Slack, Filesystem, GitHub,
Brave Search, etc.) that adopters install via `.mcp.json` directly —
no plugin wrapper.

After plugin discovery, the session also proposes relevant standalone
MCP servers based on the user's stack + integration needs. For each
candidate, the session surfaces the same vetting info as for community
plugins (license, named maintainer, recency) and requests explicit user
approval before adding.

User picks. Selected MCP servers go into the project's `.mcp.json` (see
`.mcp.json.example` for the committed-template shape — `.mcp.json`
itself is typically gitignored, since it can hold per-developer
credentials). MCP servers are separate from `VENDORED.md`'s "Installed
plugins" section — they're a different distribution model.

### Vetting rubric (third-party-authored plugins and MCP servers)

Default-deny. Scope is **any plugin whose `marketplace_entry.source`
is an object** — that includes the third-party-curated majority of
`claude-plugins-official` as well as everything in `claude-community`.
To accept such a plugin, the session must confirm:

- Explicit **license** declared (in `plugin.json` or `LICENSE`).
- **Named maintainer** (not anonymous).
- **Commit within ~6 months** (or explicit "stable, not abandoned"
  justification).
- **Explicit user approval** before install.

Surface ambiguous cases rather than auto-install. **Anthropic-authored**
plugins — those whose `marketplace_entry.source` is a string path
within `anthropics/claude-plugins-official`, including both baselines —
are trusted by default and skip this rubric. The discriminator is the
schema of the `source` field, not the marketplace name.

### Activation caveat (silent-failure trap)

After `claude plugin install <plugin>@<marketplace>`, the plugin appears
in `claude plugin list` but its hooks, agents, and skills do **not**
bind to the currently-active session until one of:

- The user runs `/reload-plugins` (slash command — only the user can
  type it; the AI session can't invoke slash commands directly).
- The session restarts.

**Why this matters during adoption.** The procedures below install
baseline plugins, then later run verification + commit the adoption.
If `/reload-plugins` is skipped, the just-installed plugins won't
review the adoption commit — they'll be active from the *next* session
start onward, so future commits in the repo get reviewed normally, but
the adoption commit itself ships unreviewed.

## First-time adoption

Two starting points. Pick the one that fits, paste the prompt into a
Claude Code session running in your *target* repo (the one you're
adopting into), with this template available at a path like
`../claude_code_template`.

> **Recommended: enter [plan mode](https://code.claude.com/docs/en/permission-modes#analyze-before-you-edit-with-plan-mode)
> first.** The procedures below have a natural read-and-decide phase
> before any writes — inspecting the target repo, enumerating plugins
> from the catalog, identifying secret-file modes that need `chmod 600`,
> planning merges for conflicting paths. Plan mode lets the session
> surface all of that as a reviewable plan before touching files; you
> can edit the plan before execution and avoid mid-flow surprises.
> Especially valuable for the existing-repo procedure, which has more
> merge decisions and more pre-existing state to reconcile.

> **If your repo already maintains a `docs/adr/` series**, vendor template
> ADRs into a sub-namespace — `docs/claude-code-template/` or
> `docs/adr/_upstream/` are both common — to avoid numbering collisions.
> The template ships `ADR-001-vendor-with-source-pin.md`,
> `ADR-002-ai-context-archive-threshold.md` (superseded — kept as historical
> record), and `ADR-004-ai-context-archive-threshold-bump.md` (live rationale
> for the `AI_CONTEXT.md` threshold + `/handoff` discipline); vendoring those
> naïvely into a repo with its own ADR-001 silently corrupts the adopter's
> ADR sequence.
> Patch the inline references in `templates/AI_SESSION_START.md` (and any
> other vendored docs that cross-link to template ADRs) to the
> sub-namespace path you chose.

### New repo (or near-empty)

Bias: generous adoption.

> Read `../claude_code_template/docs/ADOPTING.md` and adopt this template
> into the current repo. **New project.** Tech stack: `<fill in>`. Follow
> the new-repo procedure.

The session will:

1. Read `docs/ADOPTING.md`, `CLAUDE.md`, `SECURITY.md`, and
   `docs/adr/ADR-001-vendor-with-source-pin.md` from the template.
2. Capture the source SHA: `(cd ../claude_code_template && git rev-parse HEAD)`.
   Refuse to proceed on a dirty template tree.
3. Ask enough about the project (tech stack, structure, key commands) to
   fill the `CLAUDE.md` skeleton placeholders.
4. Copy every **vendor-as-is** file from the file map.
5. Copy each **adapt** file and make the project-specific edits
   (CODEOWNERS handles, `.gitignore` patterns, LICENSE holder, SECURITY
   contact).
6. Copy each **skeleton** file and fill placeholders from the user's
   answers.
7. **Repoint `@templates/...` references.** Four `@`-refs across three
   files in `.claude/commands/` point at `@templates/...`. If this
   adoption relocated or stripped `templates/`, repoint each match to
   the local layout:

   | File | `@templates/...` refs carried |
   |------|-------------------------------|
   | `.claude/commands/session-start.md` | `@templates/AI_SESSION_START.md` |
   | `.claude/commands/handoff.md` | `@templates/ADR-template.md`, `@templates/AI_SESSION_START.md` |
   | `.claude/commands/adr.md` | `@templates/ADR-template.md` |

   Quick scan to confirm: `grep -rn '@templates/' .claude/commands .claude/skills`.
   Also scan vendored skeleton templates (especially `templates/AI_SESSION_START.md`)
   for inline `docs/skill-security.md` / `docs/adr/ADR-NNN-*.md` references —
   they're prose-level path mentions rather than `@`-imports so
   `scripts/check-template.sh` doesn't catch them, but they break the same way.
   Adopters with their own `docs/adr/` series should sub-namespace template
   ADRs (see the callout above).
   `scripts/check-template.sh` (step 11 below) catches surviving `@templates/`
   refs — but can't catch refs that resolve to the wrong file, so do this
   step even if `templates/` was kept.
8. **Install baseline plugins** per [Plugins](#plugins). First check
   `claude plugin list`; for any baseline already installed at user
   scope, confirm it's enabled and skip — no re-install or re-prompt.
   For baselines not yet installed, default-install at user scope; ask
   the user to opt out per *missing* plugin.
9. **Run plugin + MCP discovery** per [Plugins](#plugins). Surface
   plugin and standalone MCP-server candidates for the user's project;
   install accepted plugins at the user's chosen scope and add accepted
   MCP servers to `.mcp.json`. **After steps 8-9 complete, if any
   plugins were installed (baseline or discovered), prompt the user
   once to run `/reload-plugins`** so hooks/agents bind to this session
   (see [Activation caveat](#activation-caveat-silent-failure-trap));
   skipping means the adoption commit ships without plugin review.
10. Create `VENDORED.md` at repo root (see [Source-pin manifest](#source-pin-manifest)),
    including the "Installed plugins" section listing baseline + discovered.
11. Run `bash scripts/check-template.sh` and
    `bash scripts/audit-config.sh .claude/`. Report.
12. Stage one atomic commit: `chore: adopt claude_code_template @ <sha>`
    with a body listing what was adopted (files + plugins).

### Existing repo (Claude Code already in use)

Bias: audit first; never stomp silently.

> Read `../claude_code_template/docs/ADOPTING.md` and adopt this template
> into the current repo. **Existing project** — already has its own
> Claude Code config / `CLAUDE.md` / etc. Follow the existing-repo
> procedure.

The session will:

1. **Audit.** For each path the template wants to vendor, check whether
   the adopter repo already has it (exact-path conflict). **Also flag
   files with the same basename at a different path** — e.g., the
   adopter has `docs/AI_SESSION_START.md` while the template vendors
   `templates/AI_SESSION_START.md`. These are silent staleness traps
   when the adopter version pre-dates a content rewrite upstream (the
   2026-05 hybrid-memory rewrite changed thresholds and removed
   references to retired scripts; an adopter who skipped past it can
   keep stale prose that contradicts the freshly-vendored code). Build
   a conflict list **and** a basename-clash list.
2. Read the template docs as above; capture source SHA; refuse on dirty
   template tree.
3. **Ask the user** how to resolve each conflict — *merge*, *replace*,
   *keep mine*, or *skip*. For known-mergeable files (`.gitignore`,
   `.claude/settings.json` deny-list), propose a specific merge. **For
   `CLAUDE.md`, propose the three-bucket merge** described in
   [§ Merging the template's `CLAUDE.md`](#merging-the-templates-claudemd)
   rather than a file-level decision. **For basename clashes, bias toward
   overwrite-or-merge** — stale adopter content is the more common failure
   mode than intentional divergence. Batch the questions; don't ask
   file-by-file.
4. For non-conflicting paths, follow steps 4–6 of the new-repo procedure.
5. For conflicting paths, apply the user's resolutions.
6. **Repoint `@templates/...` references.** Four `@`-refs across three
   files in `.claude/commands/` point at `@templates/...`. If this
   adoption relocated or stripped `templates/`, repoint each match to
   the local layout:

   | File | `@templates/...` refs carried |
   |------|-------------------------------|
   | `.claude/commands/session-start.md` | `@templates/AI_SESSION_START.md` |
   | `.claude/commands/handoff.md` | `@templates/ADR-template.md`, `@templates/AI_SESSION_START.md` |
   | `.claude/commands/adr.md` | `@templates/ADR-template.md` |

   Quick scan to confirm: `grep -rn '@templates/' .claude/commands .claude/skills`.
   Also scan vendored skeleton templates (especially `templates/AI_SESSION_START.md`)
   for inline `docs/skill-security.md` / `docs/adr/ADR-NNN-*.md` references —
   they're prose-level path mentions rather than `@`-imports so
   `scripts/check-template.sh` doesn't catch them, but they break the same way.
   Adopters with their own `docs/adr/` series should sub-namespace template
   ADRs (see the callout above).
   `scripts/check-template.sh` (step 10 below) catches surviving `@templates/`
   refs — but can't catch refs that resolve to the wrong file, so do this
   step even if `templates/` was kept.
7. **Detect already-installed plugins** via `claude plugin list`. For any
   baseline plugin not yet installed, prompt the user to opt in (default
   install). Don't double-suggest what's already there.
8. **Run plugin + MCP discovery** per [Plugins](#plugins), excluding
   plugins and MCP servers already installed/configured. **After steps
   7-8 complete, if any plugins were installed, prompt the user once
   to run `/reload-plugins`** (see
   [Activation caveat](#activation-caveat-silent-failure-trap)).
9. Create or update `VENDORED.md` (existing repos may already have one
   from a prior adoption; merge entries). Includes the "Installed plugins"
   section.
10. Run both verification scripts. Distinguish failures originating from
    template files vs. pre-existing project state.
11. Stage one atomic commit; body lists what was adopted, what was merged
    (with strategy), what was skipped, plugins installed, and the current
    pinned SHA.

## Merging the template's `CLAUDE.md`

The file map classifies `CLAUDE.md` as a "skeleton," but in practice it's a
**hybrid** — some sections are project-specific scaffolding (replace with
your own), others are template-shared engineering principles + load-bearing
framework prose (keep on merge). An adoption that treats `CLAUDE.md` as
pure skeleton drops the second group, and the rest of the template
(commands, hooks, skills) silently loses contract with it.

When the existing-repo procedure step 3 reaches `CLAUDE.md`, propose a
**three-bucket merge** rather than a file-level overwrite-or-keep decision.

### Bucket 1 — Template-shared, keep verbatim

These are the sections the rest of the template assumes exist. Bring them
into the adopter's `CLAUDE.md` unchanged.

| Section | Why it's template-shared |
|---------|--------------------------|
| `## Conventions` block (the engineering principles: don't-duplicate, types-first, defensive-defaults-at-boundaries, refactor-verify against baseline, treat `.claude/` as deps, review-before-commit, no-amend-after-push) | These are the shared engineering stance the rest of the template assumes. Skills like `verify-refactor` reference the baseline-output rule directly. |
| `## Context System` (entire section) | Load-bearing for `/handoff`, `/session-start`, hybrid-memory model, ADR/summaries archive mechanics. The template's commands, hooks, and skills assume this paragraph exists. |
| Behavioral guidelines block at the bottom (the four principles: Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution) | Referenced as the "four principles" throughout AI sessions; dropping them changes the contract for what the model is being asked to optimize for. |

### Bucket 2 — Template framing + project content

Keep the framing (the template-provided intro + structural skeleton);
replace the bracketed placeholders with the project's actual content.

| Section | Keep | Replace |
|---------|------|---------|
| `## Hard Constraints (guarded by code)` | The intro philosophy ("Critical invariants are enforced in code... never a runtime toggle/UI") + the `block-dangerous.sh` PreToolUse hook bullet (template-provided) | The `<INVARIANT>` and `<limit/threshold>` placeholders → your project's actual code-guarded invariants |
| `## Architecture Decisions` | The one-line-highlight-per-ADR format | Include ADR-001 / ADR-002 entries **only if you vendored those ADRs** (sub-namespaced or otherwise). Add your project's own ADR entries below. |
| `## AI Integration Patterns (if applicable)` | The section if your project uses LLMs | Customize the bullets freely; drop the section entirely if your project doesn't use AI integrations. |

### Bucket 3 — Pure project scaffold, replace

These exist only to give the adopter a starting structure. Replace each
with the project's actual content (or skip if the adopter already has
equivalents in their own `CLAUDE.md`).

- Project Name + one-line description
- `## Tech Stack`
- `## Project Structure`
- `## Key Files`
- `## Commands`

### After merging

Keep the merged file under **200 lines** (`CLAUDE.md` auto-loads every
session — token discipline matters here). The template's bucket-1 sections
add up to ~30 lines together; the rest is the project's responsibility.

## Source-pin manifest

`VENDORED.md` lives at the adopter's repo root. The AI session creates it
on first adoption and updates it on each re-sync. Single source of truth
for what's been vendored and from which upstream commit.

Format (proposed; adopters can customize):

```markdown
# Vendored from claude_code_template

Upstream: https://github.com/mjvacas/claude_code_template
Last sync: 2026-06-01 @ 80768f7

## Files

| Path | Upstream path | Pinned SHA | Notes |
|------|---------------|------------|-------|
| `.claude/hooks/block-dangerous.sh` | same | 80768f7 | vendor-as-is |
| `.claude/settings.json` | same | 80768f7 | merged with project's deny additions |
| `scripts/check-template.sh` | same | 80768f7 | vendor-as-is |
| `CLAUDE.md` | same | 80768f7 | skeleton — adapted to tech stack |

## Installed plugins

| Plugin | Marketplace | Scope | Installed | Source |
|--------|-------------|-------|-----------|--------|
| `security-guidance` | `claude-plugins-official` | user | 2026-06-01 | baseline |
| `pr-review-toolkit` | `claude-plugins-official` | user | 2026-06-01 | baseline |
| `commit-commands` | `claude-plugins-official` | user | 2026-06-01 | discovered |
```

**Why a sidecar (not per-file headers).** Four of the vendor-as-is files
are strict JSON with `$schema` validation (`.claude/settings.json`,
`.mcp.json.example`, the two `.claude/settings.*.example` files). They
can't carry `//` comments. A sidecar covers every file format uniformly
with one place to update on re-sync. See
[ADR-001](adr/ADR-001-vendor-with-source-pin.md) for the full rationale.

### Optional per-file headers

For files that support comments, adopters can *additionally* mark each
vendored file with a one-line header for in-situ discoverability:

```bash
# Vendored from claude_code_template @ 80768f7 — see VENDORED.md
```

```markdown
<!-- Vendored from claude_code_template @ 80768f7 — see VENDORED.md -->
```

JSON files skip these. The sidecar remains authoritative; the header is
convenience.

## File map

### Vendor as-is (copy verbatim)

| Path | Why |
|------|-----|
| `.claude/settings.json` | Deny-list + permissions baseline. |
| `.claude/settings.local.json.example` | Personal-overrides template. |
| `.claude/settings.lockdown.json.example` | Optional egress denies for untrusted skills. |
| `.claude/statusline.sh` | Status line; API-drift-defensive. |
| `.claude/hooks/session-context.sh` | Safe SessionStart hook. |
| `.claude/hooks/block-dangerous.sh` | **Critical**: PreToolUse hard-block of `rm -rf /`, `git push --force`, pipe-to-shell, etc. |
| `.claude/hooks/precompact-snapshot.sh` | Pre-compaction breadcrumb snapshots. |
| `.claude/hooks/clock.sh` | Opt-in per-prompt time heartbeat (ships unwired; a few tokens/prompt when enabled — see `docs/claude-code-setup.md`). |
| `.claude/commands/commit.md` | `/commit` slash command. |
| `.claude/commands/adr.md` | `/adr` slash command. |
| `.claude/skills/verify-refactor/` | Golden-output byte-identical diffing. |
| `.claude/skills/tune-parameters/` | Threshold-tuning skill. |
| `.claude/skills/llm-eval/` | Ground-truth accuracy harness. |
| `.editorconfig` | Universal whitespace/EOL rules. |
| `.mcp.json.example` | MCP template with vetting instructions. |
| `scripts/check-template.sh` | Template self-check (zero deps). |
| `scripts/audit-config.sh` | Vetting aid for `.claude/` content. |
| `.github/workflows/check.yml` | Runs `check-template.sh` + gitleaks on every PR/push. Without it the template's security posture isn't enforced on adopter PRs. Skip only if your CI is wired up differently. |
| `templates/ADR-template.md` | ADR scaffold (referenced by `/adr`). |
| `docs/adr/ADR-001-vendor-with-source-pin.md` | Rationale for the `VENDORED.md` sidecar manifest. Sub-namespace if you maintain your own `docs/adr/` series (see § First-time adoption callout). |
| `docs/adr/ADR-002-ai-context-archive-threshold.md` | Historical record — the original 500-line research-anchored derivation. Superseded by ADR-004 but kept in-repo (ADR-004 cites its evidence chain). Same sub-namespacing caveat. |
| `docs/adr/ADR-004-ai-context-archive-threshold-bump.md` | Live rationale for the 750-line `AI_CONTEXT.md` archive threshold + `/handoff` state-sufficiency requirement (referenced from `templates/AI_SESSION_START.md` and CLAUDE.md's Context System). Same sub-namespacing caveat. |

### Adapt (copy, then customize)

| Path | What to change |
|------|----------------|
| `.claude/commands/session-start.md` | Customize section headers per project. |
| `.claude/commands/handoff.md` | Minor tone customization. |
| `.github/CODEOWNERS` | Replace `@<owner>` with team handles. |
| `.gitignore` | Keep the security entries; append project patterns. |
| `SECURITY.md` | Fill contact placeholder; customize scope. |
| `LICENSE` | Update copyright holder. |

### Skeleton to copy (heavy edits expected)

| Path | What to do |
|------|------------|
| `CLAUDE.md` | Fill tech stack, structure, key files, commands, conventions, hard constraints. **Keep under 200 lines.** Delete the template header. |
| `AI_CONTEXT.md` | Decision log for your project; starts blank. |
| `README.md` | Replace entirely. |
| `templates/PROJECT_SPEC.md` | Optional "why/what". |
| `templates/ARCHITECTURE.md` | Optional "how". |
| `templates/BUILD_PLAN.md` | Optional "in what order". |
| `templates/AI_SESSION_START.md` | Narrative session-workflow guide. |

### Reference only (read; don't copy)

| Path | Why |
|------|-----|
| `docs/claude-code-setup.md` | How this template wires into Claude Code. Read for ideas. |
| `docs/skill-security.md` | Trust model + vetting procedures. Link rather than copy. |
| `docs/token-awareness.md` | Cost classes, the per-session context tax, and model-routing heuristic. Read; link rather than copy. |
| `CHANGELOG.md` | This template's change log. Read to re-sync. |
| `CONTRIBUTING.md` | Sending fixes back to this repo + its maintainer-side working agreements. Don't copy — write your own if your project needs one. |

### Skip

| Path | Why |
|------|-----|
| `old/` | Historical artifacts. |

## Re-syncing template updates

After adoption, re-sync periodically. Paste-prompt for the adopter's
Claude Code session:

> Re-sync vendored files from `claude_code_template` (at
> `../claude_code_template`). Check the template's `CHANGELOG.md` since
> the SHA in `VENDORED.md`; show me what's changed and propose updates.

The session will:

1. Read `VENDORED.md` to get the current pinned SHA(s), vendored paths,
   and installed plugins.
2. Read the template's `CHANGELOG.md`; identify entries affecting
   vendored paths or baseline plugins.
3. Run, against the template repo:
   `git log --oneline <pinned-sha>..HEAD -- <vendored-paths>`.
4. **Check baseline plugins** (`claude plugin list`) — install any
   baseline newly recommended by the template (per upstream
   [Plugins](#plugins)) and not yet installed; prompt opt-in per plugin.
   **If any were installed, prompt the user to run `/reload-plugins`**
   (see [Activation caveat](#activation-caveat-silent-failure-trap)).
5. **Re-run plugin + MCP discovery** for anything newly relevant to the
   project (new project areas, new ecosystem entries since last sync).
   Prompt for `/reload-plugins` again if any plugins were installed.
6. Propose specific diffs for each changed file; ask the user to approve,
   modify, or skip each.
7. Apply approved changes; bump the SHA(s) in `VENDORED.md`; update the
   "Installed plugins" section.
8. Re-run `bash scripts/check-template.sh` and
   `bash scripts/audit-config.sh .claude/`.
9. Stage one atomic commit:
   `chore: re-sync claude_code_template <old-sha>..<new-sha>`.

## Verification

After adoption or re-sync, `check-template.sh` exits non-zero on
regression — fix before committing. `audit-config.sh` is a vetting
**aid**, not a gate; legitimate config trips checks (the hooks really do
run shell commands). The AI session reads the report and decides; the
user reviews. See `docs/skill-security.md` for the trust model.

## Pointers

- [`CLAUDE.md`](../CLAUDE.md) — project conventions and the hybrid-memory model.
- [`SECURITY.md`](../SECURITY.md) — security posture summary.
- [`docs/skill-security.md`](skill-security.md) — vetting procedures.
- [`CHANGELOG.md`](../CHANGELOG.md) — what's changed in this template.
- [`docs/adr/ADR-001`](adr/ADR-001-vendor-with-source-pin.md) — sidecar-manifest rationale.
