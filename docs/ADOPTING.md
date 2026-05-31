# Adopting this template

> **Audience.** You (or me — the maintainer is also the primary adopter)
> sitting in a *different* repo with a Claude Code session open. Adoption
> is driven by that session, not by manual `cp -r`. This doc tells the
> session what to do.
>
> If you're sending a fix *back* to this repo, see (future) `CONTRIBUTING.md`
> — different doc, different audience.

## What this template is

A personal Claude Code starter: security posture (deny-list, dangerous-
command hook, secret-content scan, vetting scripts), session workflow
(`/session-start`, `/handoff`, `/commit`, `/adr`), and a hybrid memory
model (`CLAUDE.md` + `AI_CONTEXT.md` + native auto-memory + ADRs).
Language-agnostic — no build tooling, no test runner, no framework
lock-in.

Adopting doesn't have to be all-or-nothing. The file map classifies each
file by how it's meant to travel.

## First-time adoption

Two starting points. Pick the one that fits, paste the prompt into a
Claude Code session running in your *target* repo (the one you're
adopting into), with this template available at a path like
`../claude_code_template`.

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
7. Create `VENDORED.md` at repo root (see [Source-pin manifest](#source-pin-manifest)).
8. Run `bash scripts/check-template.sh` and
   `bash scripts/audit-config.sh .claude/`. Report.
9. Stage one atomic commit: `chore: adopt claude_code_template @ <sha>`
   with a body listing what was adopted.

### Existing repo (Claude Code already in use)

Bias: audit first; never stomp silently.

> Read `../claude_code_template/docs/ADOPTING.md` and adopt this template
> into the current repo. **Existing project** — already has its own
> Claude Code config / `CLAUDE.md` / etc. Follow the existing-repo
> procedure.

The session will:

1. **Audit.** For each path the template wants to vendor, check whether
   the adopter repo already has it. Build a conflict list.
2. Read the template docs as above; capture source SHA; refuse on dirty
   template tree.
3. **Ask the user** how to resolve each conflict — *merge*, *replace*,
   *keep mine*, or *skip*. For known-mergeable files (`.gitignore`,
   `.claude/settings.json` deny-list, `CLAUDE.md`), propose a specific
   merge. Batch the questions; don't ask file-by-file.
4. For non-conflicting paths, follow steps 4–6 of the new-repo procedure.
5. For conflicting paths, apply the user's resolutions.
6. Create or update `VENDORED.md` (existing repos may already have one
   from a prior adoption; merge entries).
7. Run both verification scripts. Distinguish failures originating from
   template files vs. pre-existing project state.
8. Stage one atomic commit; body lists what was adopted, what was merged
   (with strategy), what was skipped, and the current pinned SHA.

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
| `.claude/commands/commit.md` | `/commit` slash command. |
| `.claude/commands/adr.md` | `/adr` slash command. |
| `.claude/agents/code-reviewer.md` | Diff reviewer agent. |
| `.claude/skills/verify-refactor/` | Golden-output byte-identical diffing. |
| `.claude/skills/tune-parameters/` | Threshold-tuning skill. |
| `.claude/skills/llm-eval/` | Ground-truth accuracy harness. |
| `.editorconfig` | Universal whitespace/EOL rules. |
| `.mcp.json.example` | MCP template with vetting instructions. |
| `scripts/check-template.sh` | Template self-check (zero deps). |
| `scripts/audit-config.sh` | Vetting aid for `.claude/` content. |
| `templates/ADR-template.md` | ADR scaffold (referenced by `/adr`). |

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
| `templates/LLM_APP_DEVELOPMENT_BEST_PRACTICES.md` | Framework-agnostic guidelines. |
| `CHANGELOG.md` | This template's change log. Read to re-sync. |

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

1. Read `VENDORED.md` to get the current pinned SHA(s) and the list of
   vendored paths.
2. Read the template's `CHANGELOG.md`; identify entries affecting
   vendored paths.
3. Run, against the template repo:
   `git log --oneline <pinned-sha>..HEAD -- <vendored-paths>`.
4. Propose specific diffs for each changed file; ask the user to approve,
   modify, or skip each.
5. Apply approved changes; bump the SHA(s) in `VENDORED.md`.
6. Re-run `bash scripts/check-template.sh` and
   `bash scripts/audit-config.sh .claude/`.
7. Stage one atomic commit:
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
