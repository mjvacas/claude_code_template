# Adopting this template

> **Audience.** You (or me, since the maintainer is also the primary adopter)
> sitting in a *different* repo with a Claude Code session open. That session
> drives the adoption instead of a manual `cp -r`. This doc tells the
> session what to do.
>
> If you're sending a fix *back* to this repo, see
> [`CONTRIBUTING.md`](../CONTRIBUTING.md). It's a different doc for a different audience.

## What this template is

A personal Claude Code starter: security posture (deny list, dangerous
command hook, secret content scan, vetting scripts), session workflow
(`/session-start`, `/handoff`, `/commit`, `/adr`), and a hybrid memory
model (`CLAUDE.md`, `AI_CONTEXT.md`, native auto memory and ADRs).
It's language agnostic. There's no build tooling, no test runner and no
framework to lock you in.

Adopting doesn't have to be all or nothing. The file map classifies each
file by how it's meant to travel.

## Plugins

Two kinds: **baseline** (installed by default during adoption) and
**discovered** (project specific, enumerated from the local marketplace
manifest during adoption, with no freeform "search").

### Baseline plugins

Useful regardless of project. The adopter's CC session installs them by
default at user scope. The user opts out of any plugin they don't want.
Both are Anthropic-authored, so the third party vetting rubric below doesn't
apply. `claude-plugins-official` lists them with a `./plugins/` path (see
the authorship discriminator under [Plugin discovery](#plugin-discovery)).

- **`security-guidance@claude-plugins-official`**: reactive SAST and
  diff review. It catches vulnerabilities in the code Claude *writes*. That
  complements this template's *preventive* posture (deny list,
  `block-dangerous.sh` PreToolUse guard), which covers the commands Claude
  tries to *run*.
- **`pr-review-toolkit@claude-plugins-official`**: specialized PR review
  agents (`silent-failure-hunter`, `type-design-analyzer`,
  `pr-test-analyzer`, `comment-analyzer`, `code-simplifier`,
  `code-reviewer`). It replaces the `code-reviewer` agent this template
  previously shipped. It's more specialized and maintained upstream.

### Plugin discovery

For project specific plugins beyond the baseline, the session matches
the user's tech stack, domain and working style against the
**authoritative plugin catalog** instead of a freeform "search." There is
**no `claude plugin search` subcommand**. The failure mode this
procedure prevents is the session confabulating plausible sounding
plugin names (`expo@claude-plugins-official` and similar) that don't
exist in any marketplace.

**Enumeration (the session runs these in order):**

1. Refresh marketplaces:
   ```bash
   claude plugin marketplace update
   ```
2. Enumerate with Claude Code's own listing. It covers every configured
   marketplace, including the built-in `anthropic-plugin-directory`, and gives
   each plugin's source and the commit it installs:
   ```bash
   f=$(mktemp) && claude plugin list --available --json > "$f"
   # Every plugin not yet installed, as <name>@<marketplace>:
   jq -r '.available[].pluginId' "$f"
   # Full entry for a candidate (description, version, source):
   jq '.available[] | select(.pluginId == "<name>@<marketplace>")' "$f"
   ```
   Installed plugins are under `.installed`. Don't use
   `~/.claude/plugins/plugin-catalog-cache.json`, which older versions of this guide
   read. `marketplace update` can leave it months out of date.
3. Match against the user's stack **using only names that appear in
   step 2's output.** A name not in the catalog does not exist.
   Propose it and the install will fail with "not found." Confabulation
   is rejected by construction.

For each verified candidate, surface (from its listing entry or its own
files, without guessing):

- **Name, marketplace and description** (`.description`)
- **Its files**, as Claude Code would install them, in a folder you can inspect:
  `<installLocation>/<source path>` for a string source (`installLocation` is the
  marketplace's entry in `~/.claude/plugins/known_marketplaces.json`). For a `url` or
  `git-subdir` source, fetch the commit it pins (`.source.sha`), not the branch tip:
  `git init -q <tmp> && git -C <tmp> fetch -q --depth 1 <url> <sha> && git -C <tmp> checkout -q FETCH_HEAD`,
  then its `.source.path` subfolder for `git-subdir` (in zsh, don't keep it in a
  variable named `path`, because zsh ties that name to `$PATH`).
- **What runs.** `bash <template-clone>/scripts/audit-config.sh <folder>` is the
  template clone's auditor. It reports hooks, MCP and LSP servers, monitors, commands,
  permission grants and skills the model can invoke. Vet from this report.
- **Components and token cost.** `claude --plugin-dir <folder> plugin details <name>`
  prints the plugin's component inventory and its projected token cost, both always
  on and per use (the `session` and `on-use` cost classes in
  [`docs/token-awareness.md`](token-awareness.md)), without installing it. It isn't a
  complete list of what runs, so don't use it to dismiss anything the auditor reports.
- **Maintainer and last commit.** The marketplace manifest's `.author.name` when it
  has one, otherwise the source repo's owner, and
  `gh api "repos/<owner>/<repo>/commits?path=<path>&per_page=1" --jq '.[0].commit.committer.date'`.
  For a string source, `<owner>/<repo>` is the marketplace's `source.repo` in
  `known_marketplaces.json` and `<path>` is the source path without `./`.
- **How it relates to this template** (orthogonal, complementary or
  overlapping)

**License** is not in the catalog. The trust model is **based on
authorship rather than marketplace**. Being listed in `claude-plugins-official`
is curation, which doesn't establish authorship. The discriminator is where
the plugin's code lives:

```jq
# Only in the claude-plugins-official manifest (source.repo = anthropics/claude-plugins-official):
.source | type == "string" and startswith("./plugins/")   # ⇒ Anthropic-authored
```

A plugin is Anthropic-authored only when the **`claude-plugins-official`**
marketplace (its `source.repo` in `~/.claude/plugins/known_marketplaces.json`
is `anthropics/claude-plugins-official`) lists it with a source under
**`./plugins/`** (e.g., `"./plugins/security-guidance"`). That's Anthropic's own
code in that repo, trusted by default. Everything else is authored by a third
party and **needs the full vetting rubric**:
- a `./external_plugins/` path in the same repo (partner plugins, e.g.
  `context7` by Upstash, which calls a remote MCP server)
- an **object** source: `url` (a vendor's repo), `git-subdir` (a `path`
  inside a vendor's repo) or `command` (a local tool that supplies the plugin)
- any plugin from another marketplace, whatever its paths look like.

On 2026-11-18, 41 of the 317 plugins in `claude-plugins-official` were
Anthropic-authored. Another 14 sat under `./external_plugins/` and 262 had
object sources (163 `url`, 98 `git-subdir`, 1 `command`).

For each candidate authored by a third party, find the license and confirm one
is declared before installing. Look in its own `plugin.json` or folder first.
For an `./external_plugins/` path, look next at the marketplace repo's root
`LICENSE`. For a `git-subdir` source, look at `.source.path` inside
`.source.url`, then that repo's root. For a `url` source, look at the repo at
`.source.url`. A `command` source has no repo to read, so check it by hand. See
[Vetting rubric](#vetting-rubric-plugins-and-mcp-servers-by-third-parties).

User picks. Session installs (`claude plugin install <name>@<marketplace>`)
and records selections in `VENDORED.md` under "Installed plugins".

> **Adopting `claude-community`.** Only configured marketplaces are
> enumerable. To consider plugins from `claude-community`, the user
> runs `claude plugin marketplace add anthropics/claude-community`
> before step 1. Otherwise step 2 surfaces only the marketplaces already
> configured (`claude-plugins-official` and the built-in directory). All
> `claude-community` plugins are authored by third parties
> by construction, so every candidate runs the full vetting rubric.

### MCP server discovery

The Claude Code plugin marketplaces aren't the only source of useful
extensions. The broader MCP ecosystem (canonical index:
[`modelcontextprotocol/servers`](https://github.com/modelcontextprotocol/servers))
hosts standalone MCP servers (Postgres, Slack, Filesystem, GitHub,
Brave Search, etc.) that adopters install via `.mcp.json` directly,
with no plugin wrapper.

After plugin discovery, the session also proposes relevant standalone
MCP servers based on the user's stack and integration needs. For each
candidate, the session surfaces the same vetting info as for community
plugins (license, named maintainer, recency) and requests explicit user
approval before adding.

User picks. Selected MCP servers go into the project's `.mcp.json` (see
`.mcp.json.example` for the shape of the committed template). `.mcp.json`
itself is typically gitignored, since it can hold per developer
credentials. MCP servers are separate from `VENDORED.md`'s "Installed
plugins" section. They're a different distribution model.

### Vetting rubric (plugins and MCP servers by third parties)

Default deny. Scope is **every plugin that isn't a `./plugins/` path in
`claude-plugins-official`**: its object sources and `./external_plugins/`
paths, which together are the third party majority of that marketplace, plus
every plugin from any other marketplace, `claude-community` included.
To accept such a plugin, the session must confirm:

- Explicit **license** declared (in `plugin.json`, the plugin's folder, or the
  root `LICENSE` of the repo that holds it).
- **Named maintainer** (not anonymous).
- **Commit within ~6 months** (or explicit "stable, not abandoned"
  justification).
- **Explicit user approval** before install.

Surface ambiguous cases instead of installing them automatically.
**Anthropic-authored** plugins (those that `claude-plugins-official` lists
with a `./plugins/` path, including both baselines) are trusted by default
and skip this rubric. A string source alone isn't enough. `./external_plugins/`
paths are third party, as is a `./plugins/` path in any other marketplace. The
discriminator is the source path within `claude-plugins-official`. A listing
alone isn't authorship.

### Activation caveat (a trap that fails silently)

After `claude plugin install <plugin>@<marketplace>`, the plugin appears
in `claude plugin list` but its hooks, agents, and skills do **not**
bind to the currently active session until one of:

- The user runs `/reload-plugins` (a slash command only the user can
  type, since the AI session can't invoke slash commands directly).
- The session restarts.

**Why this matters during adoption.** The procedures below install
baseline plugins, then later run verification and commit the adoption.
If `/reload-plugins` is skipped, the plugins you just installed won't
review the adoption commit. They'll be active from the *next* session
start onward, so future commits in the repo get reviewed normally, but
the adoption commit itself ships unreviewed.

## Adopting for the first time

Two starting points. Pick the one that fits, paste the prompt into a
Claude Code session running in your *target* repo (the one you're
adopting into), with this template available at a path like
`../claude_code_template`.

> **Recommended: enter [plan mode](https://code.claude.com/docs/en/permission-modes#analyze-before-you-edit-with-plan-mode)
> first.** The procedures below have a natural phase of reading and deciding
> before any writes: inspecting the target repo, enumerating plugins
> from the catalog, identifying secret files whose modes need `chmod 600`,
> planning merges for conflicting paths. Plan mode lets the session
> surface all of that as a reviewable plan before touching files. You
> can edit the plan before execution and avoid surprises midway.
> It's especially valuable for the existing repo procedure, which has more
> merge decisions and more preexisting state to reconcile.

**Already adopted?** If the repo has a `VENDORED.md` from this template, don't run
either procedure below, because every vendored file would show up as a conflict. Use
[§ Re-syncing template updates](#re-syncing-template-updates) instead.

Once the vendored `.claude/settings.json` is in place, Claude Code asks
before each edit to `CLAUDE.md` or `.github/`. That's expected during
adoption. Approve them.

> **Not on GitHub?** `.github/workflows/check.yml`, `.github/CODEOWNERS` and the
> `Edit(.github/**)` ask rule in `settings.json` are GitHub specific. On GitLab or
> another host, port `check.yml`'s two steps to your CI (run
> `bash scripts/check-template.sh` and the gitleaks scan with its pinned hash), put
> CODEOWNERS where your host reads it (GitLab: the repo root, `docs/` or `.gitlab/`),
> and point the ask rule at your CI config (for example `Edit(.gitlab-ci.yml)` and
> `Edit(.gitlab/**)`). Record each as an adaptation in `VENDORED.md`.

> **If your repo already maintains a `docs/adr/` series**, vendor template
> ADRs into a namespaced subfolder (`docs/claude-code-template/` and
> `docs/adr/_upstream/` are both common) to avoid numbering collisions.
> The template ships `ADR-001-vendor-with-source-pin.md`,
> `ADR-002-ai-context-archive-threshold.md` (superseded, kept as historical
> record), `ADR-004-ai-context-archive-threshold-bump.md` (superseded, but it
> defines the `/handoff` discipline), and
> `ADR-007-ai-context-archive-threshold-1000.md` (live rationale for the
> `AI_CONTEXT.md` threshold). Vendoring those
> naïvely into a repo with its own ADR-001 silently corrupts the adopter's
> ADR sequence. A subfolder fixes paths but not names. If your series has
> its own ADR-NNN, say "upstream ADR-NNN" wherever your prose names the
> template's, or renumber it.
> Patch the inline references in `templates/AI_SESSION_START.md` (and any
> other vendored docs that link to template ADRs) to the
> subfolder path you chose.

### New repo (or nearly empty)

Bias: generous adoption.

> Read `../claude_code_template/docs/ADOPTING.md` and adopt this template
> into the current repo. **New project.** Tech stack: `<fill in>`. Follow
> the new repo procedure.

The session will:

1. Read `docs/ADOPTING.md`, `CLAUDE.md`, `SECURITY.md`, and
   `docs/adr/ADR-001-vendor-with-source-pin.md` from the template.
2. Capture the source SHA and tag:
   `(cd ../claude_code_template && git rev-parse HEAD && git describe --tags --exact-match || echo untagged)`.
   Pin to the tag when there is one. Refuse to proceed on a dirty template tree.
   **Your own repo must be clean too:** `git status --porcelain` must print
   nothing. Otherwise ask the user to commit or stash their work (an initial
   commit is fine in a new repo). If they don't, stop. Step 11's `git add -A`
   then stages only the adoption.
3. Ask, in one batch, everything the later steps need: tech stack, structure and
   key commands (the `CLAUDE.md` placeholders and which of those commands to add to
   the `settings.json` allow list), the GitHub handle or team for CODEOWNERS, the
   LICENSE holder, a security contact, whether to fill in the PROJECT_SPEC,
   ARCHITECTURE and BUILD_PLAN triad now (the blanks go in `templates/` either way,
   while copies you fill in go to `docs/<NAME>.md`), and any baseline plugin to skip.
4. Copy every **vendor-as-is** file from the file map with `cp -p`, which keeps
   the hooks and scripts executable.
5. Copy each **adapt** file and make the project specific edits
   (CODEOWNERS handles, `.gitignore` patterns, LICENSE holder, SECURITY
   contact).
6. Copy each **skeleton** file and fill placeholders from the user's
   answers. For `CLAUDE.md`, apply [§ Merging the template's `CLAUDE.md`](#merging-the-templates-claudemd)
   even though there's nothing to merge with: keep bucket 1, drop the highlights of
   the template internal ADRs (003, 005, 006), and repoint or drop pointers to
   reference-only docs.
7. **Repoint `@templates/...` references.** Four `@`-refs across three
   files in `.claude/commands/` point at `@templates/...`. If this
   adoption relocated or stripped `templates/`, repoint each match to
   the local layout. When relocating, prefer a namespaced subdir like
   `docs/claude-code-template/` over a flat `docs/`, which collides
   with the `docs/{PROJECT_SPEC,ARCHITECTURE,BUILD_PLAN}.md` triad that
   CLAUDE.md reserves:

   | File | `@templates/...` refs carried |
   |------|-------------------------------|
   | `.claude/commands/session-start.md` | `@templates/AI_SESSION_START.md` |
   | `.claude/commands/handoff.md` | `@templates/ADR-template.md`, `@templates/AI_SESSION_START.md` |
   | `.claude/commands/adr.md` | `@templates/ADR-template.md` |

   `handoff.md` also carries two `@docs/adr/ADR-007-…` refs. Repoint them too if you
   moved the template's ADRs into a subfolder. Quick scan to confirm:
   `grep -rnE '@(templates|docs/adr)/' .claude/commands .claude/skills`.
   Also scan vendored skeleton templates (especially `templates/AI_SESSION_START.md`)
   and `SECURITY.md` for inline `docs/skill-security.md` or `docs/adr/ADR-NNN-*.md`
   references. They're path mentions in prose rather than `@`-imports, so
   `scripts/check-template.sh` doesn't catch them, but they break the same way. Point
   each at the upstream URL at your pinned tag, or vendor the file (then repoint its own
   links to template only files, as in [Reference only](#reference-only-read-dont-copy)).
   Adopters with their own `docs/adr/` series should put template ADRs in a
   namespaced subfolder (see the callout above).
   `scripts/check-template.sh` § 3 (the `@`-reference resolution check, step 11
   below) fails on any `@`-ref whose target file is missing. So a `templates/`
   vendored verbatim passes, but a relocated or stripped one fails until you
   repoint. It can't verify a *resolved* ref points at the intended file, so
   double check after relocating.
8. **Install baseline plugins** per [Plugins](#plugins). First check
   `claude plugin list`. For any baseline already installed at user
   scope, confirm it's enabled and skip it, without reinstalling or prompting
   again. Baselines not yet installed get installed at user scope by default.
   Ask the user to opt out per *missing* plugin.
9. **Run plugin and MCP discovery** per [Plugins](#plugins). Surface
   plugin and standalone MCP server candidates for the user's project.
   Install accepted plugins at the user's chosen scope and add accepted
   MCP servers to `.mcp.json`. Record each candidate the user declines
   for step 10's "Considered plugins". **After steps 8 and 9 complete, if any
   plugins were installed (baseline or discovered), prompt the user
   once to run `/reload-plugins`** so hooks and agents bind to this session
   (see [Activation caveat](#activation-caveat-a-trap-that-fails-silently)).
   Skipping it means the adoption commit ships without plugin review.
10. Create `VENDORED.md` at repo root (see [Source pin manifest](#source-pin-manifest)),
    including the "Installed plugins" section listing baseline and discovered
    plugins (each with a one line purpose in its Notes),
    and "Considered plugins" for any the user declined.
11. **Stage first** (`git add -A`), then run `bash scripts/check-template.sh`
    and `bash scripts/audit-config.sh .claude/`. Report. On a clean adoption the
    auditor's HIGH sections hold only the template's own material: the `` !`…` ``
    lines in the four commands (§2), and its deny rules, `$schema` URLs, guard
    patterns and lockdown denies (§6). Anything else needs a look. (Staging first is
    what makes `check-template.sh` §4, the secret content scan, actually cover the
    files you just vendored. On an unstaged tree it silently scans nothing. See
    [Verification](#verification).)
12. Run your review plugin's code-reviewer on the staged diff (`CLAUDE.md` →
    Conventions), then commit the staged changes as one atomic commit:
    `chore: adopt claude_code_template @ <tag-or-sha>` with a body listing what was
    adopted (files and plugins). Then start a new Claude Code session. The guard and
    other hooks load at session start, so they aren't active in this one.

### Existing repo (Claude Code already in use)

Bias: audit first, never stomp silently.

> Read `../claude_code_template/docs/ADOPTING.md` and adopt this template
> into the current repo. **Existing project.** It already has its own
> Claude Code config, `CLAUDE.md`, etc. Follow the existing repo
> procedure.

The session will:

1. **Audit.** If the repo already has a `VENDORED.md` from this template, stop and
   use [§ Re-syncing](#re-syncing-template-updates). Otherwise, for each path the
   template wants to vendor, check whether
   the adopter repo already has it (a conflict on the exact path). **Also flag
   files with the same basename at a different path.** For example, the
   adopter has `docs/AI_SESSION_START.md` while the template vendors
   `templates/AI_SESSION_START.md`. These are silent staleness traps
   when the adopter version predates a content rewrite upstream, like the
   2026-05 hybrid memory rewrite, which changed thresholds and removed
   references to retired scripts. An adopter who skipped past it can
   keep stale prose that contradicts the freshly vendored code. Build
   a conflict list **and** a list of basename clashes.
2. Read the template docs as above, capture the source SHA, and refuse on a dirty
   template tree. **Your own repo must be clean too:** `git status --porcelain`
   must print nothing. Otherwise ask the user to commit or stash their work. If
   they don't, stop. Step 10's `git add -A` then stages only the adoption.
3. **Ask the user** how to resolve each conflict: *merge*, *replace*,
   *keep mine*, or *skip*. For files with a known merge (`.gitignore`,
   `.claude/settings.json` deny list), propose a specific merge. **For
   `CLAUDE.md`, propose the three bucket merge** described in
   [§ Merging the template's `CLAUDE.md`](#merging-the-templates-claudemd)
   rather than a decision on the whole file. **For basename clashes, bias toward
   overwriting or merging.** Stale adopter content is a more common failure
   mode than intentional divergence. Batch the questions instead of asking
   file by file.
4. For paths without conflicts, follow steps 4 to 6 of the new repo procedure.
5. For conflicting paths, apply the user's resolutions.
6. **Repoint `@templates/...` references.** Four `@`-refs across three
   files in `.claude/commands/` point at `@templates/...`. If this
   adoption relocated or stripped `templates/`, repoint each match to
   the local layout. When relocating, prefer a namespaced subdir like
   `docs/claude-code-template/` over a flat `docs/`, which collides
   with the `docs/{PROJECT_SPEC,ARCHITECTURE,BUILD_PLAN}.md` triad that
   CLAUDE.md reserves:

   | File | `@templates/...` refs carried |
   |------|-------------------------------|
   | `.claude/commands/session-start.md` | `@templates/AI_SESSION_START.md` |
   | `.claude/commands/handoff.md` | `@templates/ADR-template.md`, `@templates/AI_SESSION_START.md` |
   | `.claude/commands/adr.md` | `@templates/ADR-template.md` |

   `handoff.md` also carries two `@docs/adr/ADR-007-…` refs. Repoint them too if you
   moved the template's ADRs into a subfolder. Quick scan to confirm:
   `grep -rnE '@(templates|docs/adr)/' .claude/commands .claude/skills`.
   Also scan vendored skeleton templates (especially `templates/AI_SESSION_START.md`)
   and `SECURITY.md` for inline `docs/skill-security.md` or `docs/adr/ADR-NNN-*.md`
   references. They're path mentions in prose rather than `@`-imports, so
   `scripts/check-template.sh` doesn't catch them, but they break the same way. Point
   each at the upstream URL at your pinned tag, or vendor the file (then repoint its own
   links to template only files, as in [Reference only](#reference-only-read-dont-copy)).
   Adopters with their own `docs/adr/` series should put template ADRs in a
   namespaced subfolder (see the callout above).
   `scripts/check-template.sh` § 3 (the `@`-reference resolution check, step 10
   below) fails on any `@`-ref whose target file is missing. So a `templates/`
   vendored verbatim passes, but a relocated or stripped one fails until you
   repoint. It can't verify a *resolved* ref points at the intended file, so
   double check after relocating.
7. **Detect plugins that are already installed** via `claude plugin list`. For any
   baseline plugin not yet installed, prompt the user to opt in (default
   install). Don't suggest again what's already there.
8. **Run plugin and MCP discovery** per [Plugins](#plugins), excluding
   plugins and MCP servers that are already installed or configured. **After steps
   7 and 8 complete, if any plugins were installed, prompt the user once
   to run `/reload-plugins`** (see
   [Activation caveat](#activation-caveat-a-trap-that-fails-silently)).
9. Create or update `VENDORED.md` (existing repos may already have one
   from a prior adoption, so merge entries). It includes the "Installed plugins"
   section (each plugin with a one line purpose in its Notes) and "Considered plugins"
   for candidates the user declined in step 8.
10. **Stage first** (`git add -A`), then run both verification scripts (see
    [Verification](#verification) for why staging matters). Distinguish failures
    originating from template files vs. preexisting project state.
11. Run your review plugin's code-reviewer on the staged diff, then make one
    atomic commit, `chore: adopt claude_code_template @ <tag-or-sha>`. The body lists what was adopted, what was merged (with
    strategy), what was skipped, plugins installed, and the pinned tag or SHA.
    Then start a new Claude Code session. The hooks and merged settings load at
    session start.

## Merging the template's `CLAUDE.md`

The file map classifies `CLAUDE.md` as a "skeleton," but in practice it's a
**hybrid**. Some sections are project specific scaffolding (replace with
your own). Others are the template's shared engineering principles and load
bearing framework prose (keep on merge). An adoption that treats `CLAUDE.md` as
pure skeleton drops the second group. The rest of the template
(commands, hooks, skills) then silently loses contract with it.

When the existing repo procedure step 3 reaches `CLAUDE.md`, propose a
**three bucket merge** rather than a decision to overwrite or keep the whole file.

### Bucket 1: shared with the template, keep verbatim

These are the sections the rest of the template assumes exist. Bring them
into the adopter's `CLAUDE.md` unchanged.

> **One edit even in the "keep verbatim" sections:** they carry prose pointers to
> docs the file map classifies *reference-only*. `## Conventions` ends with "See
> docs/skill-security.md". `## Context System` mentions `docs/token-awareness.md`,
> `docs/claude-code-setup.md` and `docs/ADOPTING.md` and lists the `cc-task-bench`
> skill. If you didn't vendor those (the common case), the pointers dangle. Drop
> `cc-task-bench` from the skills list unless you vendored it. They're prose
> rather than `@`-imports, so `check-template.sh` §3 won't catch them. Repoint each
> to the upstream URL at your pinned tag
> (`https://github.com/mjvacas/claude_code_template/blob/<tag>/docs/<file>`) or drop
> the clause. Everything else in these sections stays verbatim.

| Section | Why the template shares it |
|---------|--------------------------|
| `## Conventions` block (the engineering principles: don't duplicate, keep entry points thin, types first, defensive defaults at boundaries, verify refactors against a baseline, personal info stays local, treat `.claude/` as deps, review before commit, no amend after push) | These are the shared engineering stance the rest of the template assumes. Skills like `verify-refactor` reference the baseline output rule directly. |
| `## Context System` (entire section) | Load bearing for `/handoff`, `/session-start`, the hybrid memory model, and the archive mechanics for ADRs and summaries. The template's commands, hooks, and skills assume this paragraph exists. |
| Behavioral guidelines block at the bottom (the four principles: Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution) | Referenced as the "four principles" throughout AI sessions. Dropping them changes the contract for what the model is being asked to optimize for. |

### Bucket 2: template framing and project content

Keep the framing (the intro and structural skeleton the template provides)
and replace the bracketed placeholders with the project's actual content.

| Section | Keep | Replace |
|---------|------|---------|
| `## Hard Constraints (guarded by code)` | The intro philosophy ("Critical invariants are enforced in code... never in a runtime toggle or UI") and the `block-dangerous.sh` PreToolUse hook bullet (provided by the template) | The `<INVARIANT>` and `<limit/threshold>` placeholders → your project's actual invariants guarded by code |
| `## Architecture Decisions` | The format: a one line highlight per ADR | Keep the ADR-001, ADR-002, ADR-004 and ADR-007 entries **only for the ADRs you vendored** (in a subfolder or not). Drop ADR-003, ADR-005 and ADR-006, which are template internal. Add your project's own ADR entries below. |
| `## AI Integration Patterns (if applicable)` | The section if your project uses LLMs | Customize the bullets freely. Drop the section entirely if your project doesn't use AI integrations. |

### Bucket 3: pure project scaffold, replace

These exist only to give the adopter a starting structure. Replace each
with the project's actual content (or skip if the adopter already has
equivalents in their own `CLAUDE.md`).

- Project Name and one line description
- `## Tech Stack`
- `## Project Structure`
- `## Key Files`
- `## Commands`

### After merging

Keep the merged file under **200 lines** (`CLAUDE.md` loads automatically every
session, so token discipline matters here). The template's bucket 1 sections
add up to about 40 lines together. The rest is the project's responsibility.

## Source pin manifest

`VENDORED.md` lives at the adopter's repo root. The AI session creates it
on first adoption and updates it on each re-sync. It's the single source of
truth for what's been vendored and from which upstream commit.

Pin to a **release tag** (the latest one) once releases are cut. SemVer makes
the upgrade legible (am I behind? is it breaking?), per
[ADR-006](adr/ADR-006-versioning-and-release-management.md). Until the first
tag exists (or for anything vendored between releases), pin by **commit SHA**.
The SHA is always the exact anchor. The `<tag-or-sha>` placeholders below
work either way. A SHA from a branch that hasn't been released yet (a release
candidate, say) can drop out of the template's history if that branch is squash
merged or rebase merged, so repin to the release tag once it's out.

Format (a proposal adopters can customize):

```markdown
# Vendored from claude_code_template

Upstream: https://github.com/mjvacas/claude_code_template
Last sync: <tag-or-sha>   (e.g. v0.2.1 @ 10f58a0; for an untagged release candidate,
                           6f20ee5, untagged v0.3.0 release candidate: re-pin to the tag)

## Files

| Path | Upstream path | Pinned SHA | Notes |
|------|---------------|------------|-------|
| `.claude/hooks/block-dangerous.sh` | same | <sha> | vendor-as-is |
| `.claude/settings.json` | same | <sha> | merged with project's deny additions |
| `scripts/check-template.sh` | same | <sha> | vendor-as-is |
| `CLAUDE.md` | same | <sha> | skeleton — adapted to tech stack |

## Installed plugins

| Plugin | Marketplace | Scope | Installed | Source | Notes |
|--------|-------------|-------|-----------|--------|-------|
| `security-guidance` | `claude-plugins-official` | user | 2026-06-01 | baseline | security review of code Claude writes |
| `pr-review-toolkit` | `claude-plugins-official` | user | 2026-06-01 | baseline | PR review agents, including code-reviewer |
| `context7` | `claude-plugins-official` | project | 2026-06-01 | discovered | for library docs lookups; third-party (license: marketplace repo root); audited 2026-11-18 at `43fd1f9db094`, kept |

## Considered plugins

| Plugin | Date | Why declined |
|--------|------|--------------|
| `<name>@<marketplace>` | 2026-11-18 | overlaps the baseline reviewer |

## Third-party skills

| Path | Upstream | Pinned | License | Local patches (re-apply on every bump) |
|------|----------|--------|---------|----------------------------------------|
| `.claude/skills/<name>/` | `<vendor>/<repo>` `<dir>/` | `<tag>` = `<sha>` | Apache-2.0 | 1. `disable-model-invocation: true` · 2. fallback note atop `SKILL.md` |

## Deliberately not vendored

| Path | Why skipped |
|------|-------------|
| `.claude/skills/cc-task-bench/`, `bench/` | Reference-only / template-internal benchmark. |
| `docs/adr/ADR-003/005/006-*` | Template-internal R&D ADRs. |
| `docs/token-awareness.md`, `CONTRIBUTING.md` | Reference-only — read, don't copy. |
```

The optional **`## Deliberately not vendored`** section records reference-only and
skip files you intentionally left out, so a re-sync's check for files to add
(§ Re-syncing, step 4) doesn't keep proposing them as "missed."

The optional **`## Considered plugins`** section records discovery candidates the
user declined, so a re-sync's discovery (§ Re-syncing, step 6) doesn't keep
proposing them. The "Installed plugins" Notes column starts with a one line
purpose when you install a plugin and holds third party audit decisions
(§ Re-syncing, step 5), so a later audit can say what the plugin is for.

The optional **`## Third-party skills`** section records skills vendored from
outside this template and the local patches to reapply when you bump them (see
`docs/skill-security.md` → Partial vendoring).

**Why a sidecar instead of per file headers.** Four of the vendored files
are strict JSON with `$schema` validation (`.claude/settings.json`,
`.mcp.json.example`, the two `.claude/settings.*.example` files). They
can't carry `//` comments. A sidecar covers every file format uniformly
with one place to update on re-sync. See
[ADR-001](adr/ADR-001-vendor-with-source-pin.md) for the full rationale.

### Optional headers in each file

For files that support comments, adopters can *additionally* mark each
vendored file with a one line header, so it's discoverable in place:

```bash
# Vendored from claude_code_template @ <sha> — see VENDORED.md
```

```markdown
<!-- Vendored from claude_code_template @ <sha> — see VENDORED.md -->
```

JSON files skip these. The sidecar remains authoritative. The header is a
convenience.

## File map

Some files only work together. Take each of these sets whole or not at all:

- **Session context:** `/session-start` and `/handoff`, `AI_CONTEXT.md` (and its
  `@AI_CONTEXT.md` line in `CLAUDE.md`'s Context System), `templates/AI_SESSION_START.md`,
  `docs/summaries/`, ADR-002, ADR-004 and ADR-007, and the `session-context.sh` hook with its
  `settings.json` wiring. `/handoff` also uses the Decisions set.
- **Decisions:** `/adr`, `templates/ADR-template.md` and `docs/adr/`.
- **Safety:** `settings.json`, `block-dangerous.sh`, `statusline.sh`, `check-template.sh`,
  `audit-config.sh` and `check.yml`.

Today the template expects all three. `check-template.sh` requires `docs/adr/`
and `docs/summaries/`. `/handoff` imports the ADR
template. So skipping a set means editing the others. Within a set, the check catches some
gaps (a missing `@`-import target, a wired hook whose script is gone) but not all.
Dropping `/session-start` alone, for example, passes.

### Vendor as-is (copy verbatim)

| Path | Why |
|------|-----|
| `.claude/settings.local.json.example` | Template for personal overrides. |
| `.claude/settings.lockdown.json.example` | Optional egress denies for untrusted skills. |
| `.claude/statusline.sh` | Status line, defensive against API drift. |
| `.claude/hooks/session-context.sh` | Safe SessionStart hook. |
| `.claude/hooks/block-dangerous.sh` | **Critical**: PreToolUse hard block of `rm -rf /`, `git push --force`, piping to a shell, etc. |
| `.claude/hooks/clock.sh` | Opt-in per-prompt time heartbeat. It ships unwired and costs a few tokens per prompt when enabled (see `docs/claude-code-setup.md`). |
| `.claude/commands/commit.md` | `/commit` slash command. |
| `.claude/commands/adr.md` | `/adr` slash command. Carries an `@templates/ADR-template.md` ref. Repoint it if you relocate or strip `templates/` (new repo step 7, existing repo step 6). |
| `.claude/skills/verify-refactor/` | Byte for byte diffing against golden output. |
| `.claude/skills/tune-parameters/` | Skill for tuning thresholds. |
| `.claude/skills/llm-eval/` | Accuracy harness against ground truth. |
| `.editorconfig` | Universal whitespace and EOL rules. |
| `.mcp.json.example` | MCP template with vetting instructions. |
| `scripts/check-template.sh` | Template self-check (zero deps). |
| `scripts/audit-config.sh` | Vetting aid for `.claude/` content. |
| `.github/workflows/check.yml` | Runs `check-template.sh` and gitleaks on every PR and push. Without it the template's security posture isn't enforced on adopter PRs. Skip only if your CI is wired up differently. |
| `templates/ADR-template.md` | ADR scaffold (referenced by `/adr`). |
| `docs/adr/ADR-001-vendor-with-source-pin.md` | Rationale for the `VENDORED.md` sidecar manifest. Put it in a namespaced subfolder if you maintain your own `docs/adr/` series (see the § Adopting for the first time callout). |
| `docs/adr/ADR-002-ai-context-archive-threshold.md` | Historical record of the original 500 line derivation, anchored in research. Superseded by ADR-004 but kept in the repo (ADR-004 cites its evidence chain). Same subfolder caveat. |
| `docs/adr/ADR-004-ai-context-archive-threshold-bump.md` | Superseded by ADR-007 but kept. It defines the `/handoff` state sufficiency requirement that ADR-007 keeps. ADR-007 also cites it. Same subfolder caveat. |
| `docs/adr/ADR-007-ai-context-archive-threshold-1000.md` | Live rationale for the `AI_CONTEXT.md` archive threshold (referenced from the SessionStart hook, `/handoff`, `templates/AI_SESSION_START.md` and CLAUDE.md). Same subfolder caveat. |
| `docs/adr/.gitkeep` | Keeps `docs/adr/` under version control. `check-template.sh` §5 requires the directory. Needed if you move the template's ADRs to a subfolder and have none of your own yet. |
| `docs/summaries/.gitkeep` | Keeps the (initially empty) monthly summary archive dir under version control. **Easy to miss.** It's the only file under `docs/summaries/`. Without it, `check-template.sh` §5 fails (`missing directory: docs/summaries`). Copying it is what makes a fresh adoption pass verification. |

### Adapt (copy, then customize)

| Path | What to change |
|------|----------------|
| `.claude/settings.json` | Permissions baseline and hook wiring. Add your own allow rules, denies and hooks. It wires three scripts (`block-dangerous.sh`, `session-context.sh`, `statusline.sh`). `check-template.sh` §5 fails if one is missing, so remove a script and its wiring together and record that in `VENDORED.md`. |
| `.claude/commands/session-start.md` | Customize section headers per project. |
| `.claude/commands/handoff.md` | Minor tone customization. |
| `.github/CODEOWNERS` | Replace the owner handle with your own GitHub handle or team. It **ships as `@mjvacas`** (the template maintainer) instead of a `@<owner>` placeholder. Run `grep @mjvacas .github/CODEOWNERS` to find every line, or you silently leave the maintainer as code owner of your security critical files. Then delete the `# ADOPTERS:` comment block, which a find and replace would turn into nonsense. |
| `.gitignore` | Keep the security entries and append project patterns. Drop the `bench/results/` lines unless you vendored `cc-task-bench`. |
| `SECURITY.md` | Add a private contact if you want one. Customize scope. |
| `LICENSE` | Update copyright holder. |

### Skeleton to copy (heavy edits expected)

| Path | What to do |
|------|------------|
| `CLAUDE.md` | Fill tech stack, structure, key files, commands, conventions, hard constraints. **Keep under 200 lines.** Delete the template header. |
| `AI_CONTEXT.md` | Decision log for your project. Keep the header and delete the sample session block. Required by `/session-start` and `CLAUDE.md`, which `@`-import it. |
| `README.md` | New repo: replace it with your own. Existing repo: keep yours and don't copy this one. |
| `templates/PROJECT_SPEC.md` | Optional "why and what". |
| `templates/ARCHITECTURE.md` | Optional "how". |
| `templates/BUILD_PLAN.md` | Optional "in what order". |
| `templates/AI_SESSION_START.md` | Narrative guide to the session workflow. Required by `/session-start` and `/handoff`, which `@`-import it. |

### Reference only (read, don't copy)

| Path | Why |
|------|-----|
| `docs/ADOPTING.md` | This procedure. The adopting session reads it from your template clone. Don't copy it. |
| `docs/claude-code-setup.md` | How this template wires into Claude Code. Read for ideas. |
| `docs/skill-security.md` | Trust model and vetting procedures. Link rather than copy. |
| `docs/token-awareness.md` | Cost classes, the per session context tax, compaction, and the model routing heuristic. Read it. Link rather than copy. |
| `scripts/compaction-report.sh` | Lists your recent Claude Code compactions and which were idle. It reads your transcripts in `~/.claude`, not project files, so run it from your template clone. Nothing in your repo depends on it. |
| `.claude/skills/cc-task-bench/` | Benchmark *methodology* for model routing (per ADR-003, V1 is the design and fixture layout, with the runner in V2). Read it if you want to benchmark which model to route a task type to. It's not needed to adopt the template. |
| `docs/adr/ADR-003-cc-task-bench-scope.md` | Scopes the cc-task-bench benchmark. Template internal R&D. Don't vendor. |
| `docs/adr/ADR-005-token-awareness-legibility.md` | Records the template's own token awareness decision (the statusline itself ships via `.claude/statusline.sh`). Template internal. Don't vendor. |
| `docs/adr/ADR-006-versioning-and-release-management.md` | How the *template* is versioned and released. Template internal. Don't vendor. |
| `CHANGELOG.md` | This template's change log. Read to re-sync. |
| `CONTRIBUTING.md` | How to send fixes back to this repo, plus the maintainer's working agreements. Don't copy it. Write your own if your project needs one. |

If you vendor one of these docs anyway (adopters often keep `skill-security.md` or
`token-awareness.md`), its links to template only files dangle: `docs/ADOPTING.md`,
`CONTRIBUTING.md`, ADR-003, ADR-005, ADR-006 and `scripts/compaction-report.sh`. Repoint
them to upstream URLs at your pinned tag, record the file as adapted in `VENDORED.md`,
and reapply the repoints on each re-sync.

### Skip

| Path | Why |
|------|-----|
| `bench/` | The template's own benchmark corpus, schema, and `pricing.json` (per ADR-003). Template internal. Read the schema via the `cc-task-bench` skill above if you're designing your own fixtures. |
| `tests/`, `.github/workflows/template-tests.yml` | Regression tests for the template's own scripts and hooks (`tests/<suite>/`) and the CI workflow that runs them. Template internal. The vendored `check.yml` doesn't reference them. |

## Re-syncing template updates

After adoption, re-sync periodically. A prompt to paste into the
adopter's Claude Code session:

> Re-sync vendored files from `claude_code_template` (at
> `<template-clone>`). Check the template's `CHANGELOG.md` since
> the version or SHA in `VENDORED.md`. Show me what's changed and propose updates.

Replace `<template-clone>` with the clone's absolute path. A relative one resolves
from wherever the session runs. With more than one clone around, it can point at
the wrong one.

The session will:

1. Read `VENDORED.md` to get the current pinned tag or SHAs, vendored paths,
   and installed plugins. In the template clone, refuse on a dirty tree, run
   `git fetch --tags`, and check out the **target** detached
   (`git -C <template-clone> switch --detach <tag-or-sha>`). The target is the latest
   release tag (or a commit, if you're syncing past it). `git describe --tags <pin>` shows
   where your pin sits relative to the tags. If another session may be using the same
   clone, leave it where it is. Extract the target into a new folder instead
   (`git -C <template-clone> archive <target> > <dir>.tar && mkdir <dir> && tar -xf <dir>.tar -C <dir>`)
   and use that folder wherever these steps read the template's files or run its
   scripts. Make `<dir>` an absolute path outside both repos (under `$TMPDIR`, say).
   Inside your repo, the extracted files would fail the clean check below or get staged
   with the re-sync. Don't pipe `git archive` into `tar`. A wrong target then leaves an
   empty folder and a zero exit code. History commands (`git log`,
   `git show <pin>:<path>`) still run in the clone.
   **Your own repo must be clean too:**
   `git status --porcelain` must print nothing. Otherwise ask the user to commit or
   stash their work. If they don't, stop. Step 9's `git add -A` then stages only
   the re-sync. A `git worktree` on a new branch
   (`git worktree add -b resync ../<repo>-resync main`) also works and leaves work in
   progress in place. Gitignored local files (`.env`, `.claude/snapshots/`, private
   lists) aren't in it, so the checks see a different tree. Merge the branch into your
   main branch after step 10, before starting the new session.
2. Read the template's `CHANGELOG.md` from the first section after your pin up to
   the target. A MAJOR (or, in 0.x beta, MINOR) bump flags a breaking change to the
   adoption contract. Identify entries affecting vendored paths or baseline
   plugins, including **file deletions, additions, plugin swaps, and
   Migration items**. A pin between two tags already has part of the next
   section. Step 3's log is the ground truth for what's new. If your pin predates
   `v0.1.0`, also read the date stamped prehistory sections after it, because changes
   there won't show as a SemVer bump.
3. Run, against the template repo:
   `git log --oneline <pin>..<target> -- <upstream-paths>`, taking the paths from
   `VENDORED.md`'s **Upstream path** column (a relocated file keeps its template path
   there, while your local path would silently match nothing). Pass each path as its own
   argument. In zsh, an unquoted `$paths` isn't split, so the log comes back empty. An
   empty log for an old pin means the command is wrong, not that nothing changed. Add `--diff-filter=D` to spot
   files **deleted upstream** (handled in step 7). Then check for **drift**. For each
   row, run `git -C <template-clone> show <pin>:<upstream-path> | diff - <local-path>`,
   where `<template-clone>` is the clone path from the prompt you pasted.
   A row recorded as vendor-as-is whose copy differs has local changes nobody
   recorded. Treat it as **Merge** in step 7 and record the change in its Notes, or a
   plain update will silently drop it. For example, if you wired your own hook into
   `settings.json`, the diff shows it as a `>` line (`> "command": "…/my-hook.sh"`).
   That row goes to Merge. For an adapted row, compare the drift against its Notes
   too. Record any adaptation the Notes don't list, or step 7's Merge may drop it. A
   per file `Vendored from claude_code_template` header line (either form in
   [Optional headers in each file](#optional-headers-in-each-file)) and the blank line after it
   aren't drift. Then compare each row's
   recorded class (vendor-as-is, adapted, skeleton) with the target's
   [File map](#file-map). A file the map now classes as Adapt or Skeleton that your row
   still calls vendor-as-is goes to Merge. Fix its row as well. A plain Update would
   overwrite your version (`LICENSE` would get the template's copyright holder).
4. **Check for newly vendored files.** Compare the template's current
   [File map](#file-map) against the paths in your `VENDORED.md`. Propose
   **adding** any vendor-as-is file you never picked up. The most important one is
   `.github/workflows/check.yml`, without which the security self-check isn't
   enforced on your PRs. Skip anything recorded in your "Deliberately not
   vendored" section, whatever its heading level or format. Don't propose
   deliberate skips again. Also skip a row whose own note makes it conditional when the
   condition doesn't hold (e.g. `docs/adr/.gitkeep` only matters while `docs/adr/`
   has no files). Record the skip in that section. A row under any heading of
   `VENDORED.md` (a customizations list, say) counts as recorded. If a mapped path
   already exists locally but has no row anywhere, diff
   it against the target, keep yours or take upstream, and add the row. New
   reference-only and skip files aren't proposed here. They show up in the
   `CHANGELOG`.
   Also add any file a *changed* command or skill now references (e.g. an updated
   `handoff.md` that references `docs/adr/ADR-007-…` also requires vendoring
   ADR-007). If an incoming ADR's number already exists in your own `docs/adr/`
   series, **move it to a subfolder or renumber it**. Don't assume the template's
   `ADR-NNN` slot is free.
5. **Check plugins** (`claude plugin list`) against the whole "Installed plugins"
   section, not just the baselines, and fix the section where they differ. The
   section records the baselines and the plugins this project uses, at any scope. The
   session can't tell which those are, so ask the user. Leave out user scope
   plugins installed only for other projects. Install any baseline newly recommended
   by the template (per upstream [Plugins](#plugins)) and not yet installed. Prompt
   for opt-in per plugin. Then audit each third party plugin you add to the record and
   audit each recorded one again (authorship per [Plugin discovery](#plugin-discovery)):
   - Find the copy Claude Code loads for this project (user scope, or project scope
     here), not the newest cache folder or another project's install:
     `jq -r --arg p "$(git worktree list --porcelain | sed -n '1s/^worktree //p')" '.plugins["<name>@<marketplace>"][]? | select(.scope == "user" or .projectPath == $p) | .installPath' ~/.claude/plugins/installed_plugins.json`
     (`$p` is your main checkout, even when you work in a worktree).
     No output means it isn't installed for this project. Fix its row instead.
   - Audit it again when that path's version (its last folder) differs from the one in
     the plugin's Notes, or when this range changed `scripts/audit-config.sh` or
     the vetting docs.
   - A plugin whose MCP server starts `@latest` (the official `playwright` does) runs
     the newest release of that server whatever the plugin's own version says. If its
     Notes record it as unpinned and accepted, or as replaced by a pinned `.mcp.json`
     entry, don't ask again unless its launch command changed. Otherwise show the
     command and ask whether to accept it or pin it (`docs/skill-security.md` →
     Vetting an MCP server).
   - Run the target's auditor (in the clone, or in the step 1 folder if you extracted
     one), since your own copy is still the pin's:
     `bash <template-clone>/scripts/audit-config.sh <installPath>`. Read the
     report rather than the exit code, because nearly every plugin trips `--strict` on the
     links in its LICENSE or README. `claude plugin details <name>@<marketplace>`
     adds its component inventory and token cost, but it isn't a complete list of
     what runs, so vet from the report. Show the user what runs or reaches out: §2 hits,
     MODEL-INVOCABLE entries in §4, commands in §5, and §6 hits other than license
     and README links. Ask whether to keep, disable or uninstall it. Its Notes should
     say what it's for. If they don't, ask what it's for. Record the decision, the date
     and the audited version in its Notes.

   **If any were installed, prompt the user to run `/reload-plugins`**
   (see [Activation caveat](#activation-caveat-a-trap-that-fails-silently)).
6. **Rerun plugin and MCP discovery** per [Plugin discovery](#plugin-discovery)
   when the project's stack changed since the last sync or when the user asks.
   Otherwise say it was skipped and why. The last sync is the last adoption or
   re-sync commit
   (`base=$(git log -1 --format=%H -E --grep='^chore: (adopt|re-sync) claude_code_template' -- VENDORED.md)`).
   The stack changed if a dependency manifest changed anywhere in the repo
   (`git diff --name-only "$base"..HEAD | grep -E '(^|/)(package\.json|pyproject\.toml|requirements[^/]*\.txt|go\.mod|Cargo\.toml|Gemfile)$'`)
   or a top level directory is new
   (`comm -13 <(git ls-tree -d --name-only "$base" | sort) <(git ls-tree -d --name-only HEAD | sort)`).
   If `base` comes back empty (an older adoption commit used another subject), show
   `git log --oneline -- VENDORED.md`, ask the user which commit was the last
   adoption or re-sync, and use that. Never run the checks with an empty `base`.
   Discovery here uses the target's auditor, as in step 5.
   A repo without code (notes, docs) won't trip the manifest check. There, ask the
   user whether they've taken up a new tool or workflow since the last sync. If they
   have, run discovery. Candidates are catalog entries that match
   the stack, minus what's installed and what "Considered plugins" records as
   declined. The output is a short list with the fields discovery surfaces, or
   "no new candidates". Record each candidate the user declines (name, date,
   reason) under "Considered plugins" so the next sync doesn't propose it again.
   Prompt for `/reload-plugins` again if any plugins were installed.
7. Propose changes **batched by action** (update, add, delete, merge) instead of
   one approval per file. Show the whole batch in a message of its own, outside
   the approval prompt, then ask for one approval. A long list written above a prompt
   can scroll out of view.
   - **Update.** For changed files whose `VENDORED.md` Notes say vendor-as-is
     and whose copy matched the pin in step 3, propose the target copy,
     **unless `VENDORED.md` records a path adaptation for that file** (e.g.
     `adr.md`'s repoint of `@templates/` to your layout). In that case, reapply
     the adaptation instead of copying blindly, or the update reintroduces refs
     that dangle. Go by the Notes, not the file map class.
   - **Add.** The newly vendored files from step 4.
   - **Delete.** For files removed upstream, propose removing the local copy
     **and its `VENDORED.md` row**. If the `CHANGELOG` notes a replacement
     (e.g. a dropped agent superseded by a baseline plugin), surface that swap.
     Then grep the repo for the deleted file's basename and fix prose that still
     mentions it.
   - **Merge.** For adapted or skeleton files you customized, don't copy blindly.
     If `CLAUDE.md` changed upstream, reapply only the bucket 1 (keep verbatim)
     changes per [§ Merging the template's `CLAUDE.md`](#merging-the-templates-claudemd).
     Leave your project specific content alone. Same for any `.claude/commands/*`
     whose `@templates/` or `@docs/adr/` refs you repointed. Take the upstream
     body, then reapply your repoint. For `.claude/settings.json`, start from the
     target copy and add back your own allow, ask and deny rules. Vet each allow
     rule again the way the template vetted its own. A broad one also approves
     destructive forms. `Bash(find:*)` allows `find -delete` and `-exec rm`.
     `Bash(rg:*)` allows `rg --pre <cmd>`. Narrow such a rule or move it to `ask`.
     Then put each of your hook entries back under the matching event and matcher.
     Never drop a local hook (`check-template.sh` can't tell that one is missing).
     "Your own" means what the step 3 drift diff adds against the pin. Rules the
     pin shipped and the target dropped stay dropped. **Your `VENDORED.md` Notes
     win here too:** if a row says you don't take upstream changes (a `CLAUDE.md`
     that diverged on purpose, a skeleton you replaced entirely), leave the file
     alone and say in its Notes what upstream changed. Migration items still apply
     to it.
   - **Migrate.** Apply every item in the **Migration** section of each release in
     the `CHANGELOG` range (a `chmod`, a changed default, a setting to add), including
     ones about your own files rather than vendored ones, or verification can fail on
     state the new files expect. An item whose target doesn't exist locally does nothing.

   A file in one of the file map's sets that you keep at another path, or record in
   another `VENDORED.md` section (your own copy of `AI_SESSION_START.md`, say), still
   gets that set's changes. Find it and merge them. Order matters when you re-sync in
   place, because the session runs with the files as you change them. A copied hook
   acts at once, so delete a hook at the end, in the same change that removes its
   `settings.json` wiring. Merge `settings.json` last so its new `ask` rules don't
   prompt on the rest of the re-sync.

   After Update and Merge, run `grep -rnE '@(templates|docs/adr)/' .claude/commands .claude/skills`.
   A surviving ref dangles (and fails § 3 at step 9) unless its target sits at
   that path. Repoint or restore before committing. The grep only lists refs.
   `check-template.sh` § 3 is what checks they resolve.
8. Apply approved changes. In `VENDORED.md`, set "Last sync" to the target and bump
   the pin of every row you reviewed against it, including rows you deliberately
   didn't take (their Notes say what wasn't merged, per step 7). Update the
   "Installed plugins" section. **Backfill the required sections missing relative to the current schema
   above** ("Files", "Installed plugins"). Add the optional ones only when they have
   content.
9. **Stage first** (`git add -A`), then rerun `bash scripts/check-template.sh` and
   `bash scripts/audit-config.sh .claude/`. Distinguish failures from template files
   vs. preexisting project state. If `.claude/worktrees/` holds worktrees whose work
   is merged, ask the user whether to remove them first (`git worktree remove <path>`).
   Each one's `.claude/` is config a session there still loads, often the version from
   before the sync. They also fill most of the report.
10. Run your review plugin's code-reviewer on the staged diff, then stage one atomic
    commit: `chore: re-sync claude_code_template <old-ref>..<new-ref>`. The commit
    body and `VENDORED.md` are the record. Mention the re-sync in your next
    `/handoff` rather than adding a session block just for it. Then start a new
    Claude Code session. Hooks and the merged settings load at session start.

## Uninstalling and backing out

Changed your mind? The whole footprint is reversible. Adoption lands as **one
atomic commit** and `VENDORED.md` is the bill of materials. Pick the path that
matches how you adopted. A Claude Code session can drive this, or you can do it by hand.

First, find the adoption commit (and any later re-syncs):

> `git log --oneline --grep "claude_code_template"`

**Existing repo (adopted on top of prior history), the clean path:**

1. `git revert <adoption_sha>`. The vendored files **and** the three bucket merge into
   `CLAUDE.md`, plus the merges into `.gitignore` and the `.claude/settings.json` deny
   list, all shipped in that single commit, so one revert restores your state from before the adoption
   in one move. There's no manual unmerging.
2. *Caveat:* if you edited vendored files or **re-synced** after adopting, a plain
   revert will conflict. Fall back to the manual path below, using `VENDORED.md` →
   `## Files` as the delete list and restoring your own `CLAUDE.md` and settings
   from before the adoption by hand.

**New repo (the template was the initial scaffold):** there is no state from before the
adoption to revert to. Delete the paths listed in `VENDORED.md` → `## Files` (`.claude/`, `docs/`,
`scripts/`, `templates/`, `.github/workflows/check.yml`, `VENDORED.md`, …) and strip the
template buckets from `CLAUDE.md`.

**Both paths: clean up what lives outside the repo.** `git revert` only touches tracked
files, so these survive a revert:

- **Plugins.** Run `claude plugin uninstall <name>@<marketplace>` at the scope in each
  row of `VENDORED.md` → `## Installed plugins` (they live under `~/.claude/`, outside
  your repo). Leave a user scope plugin, such as a baseline, installed if another
  project still uses it.
- **MCP servers.** Remove any entries you added to `.mcp.json`.

Traps to avoid:

- **Don't blindly `rm` the merged files** (`CLAUDE.md`, `.claude/settings.json`,
  `.gitignore`). They hold *your* content alongside the template's. Revert or unmerge
  surgically. Deleting them outright nukes your own config.
- **Plugins and MCP servers live outside the repo.** Reverting the commit won't remove
  them. `VENDORED.md` → `## Installed plugins` is your checklist.
- **Remove as a consistent set.** A half removed template (kept CI but deleted `scripts/`,
  or kept a command but deleted the `@templates/` target it references) breaks in exactly
  the ways `scripts/check-template.sh` § 3 is built to catch. Run it to confirm nothing
  specific to the template dangles. A **full** removal deletes the script itself, though,
  so run it *before* the final delete (or from a copy you kept aside). After a full
  removal there's nothing specific to the template left to dangle anyway.
- **Sweep empty dirs and the `.gitkeep`.** Deleting the files the manifest lists leaves empty
  parent dirs (`scripts/`, `.claude/hooks/`, `docs/adr/`) and, since `docs/summaries/.gitkeep`
  is a vendored file, an orphaned `docs/summaries/` if you miss its `VENDORED.md` row.
  `find . -type d -empty -delete` clears the empties (it won't touch dirs that still hold
  your own files).

## Verification

After adoption or re-sync, `check-template.sh` exits nonzero on
regression. Fix it before committing. **Stage your changes (`git add -A`) before
running it.** The integrity checks (§1 JSON validity, §3 `@`-reference
resolution) cover tracked files *and* untracked files that aren't ignored, so they
work either way. But the §4 secret content scan runs only over tracked or staged content
(it uses `git grep`), so an unstaged adoption leaves that section scanning nothing
while still printing "ok". Stage first and it covers the files you just vendored.
`audit-config.sh` is a vetting **aid**. It isn't a gate. Legitimate config trips checks
(the hooks do run shell commands). The AI session reads the report and
decides. The user reviews. See `docs/skill-security.md` for the trust model.

## Pointers

- [`CLAUDE.md`](../CLAUDE.md): project conventions and the hybrid memory model.
- [`SECURITY.md`](../SECURITY.md): security posture summary.
- [`docs/skill-security.md`](skill-security.md): vetting procedures.
- [`CHANGELOG.md`](../CHANGELOG.md): what's changed in this template.
- [`docs/adr/ADR-001`](adr/ADR-001-vendor-with-source-pin.md): rationale for the sidecar manifest.
