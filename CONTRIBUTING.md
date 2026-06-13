# Contributing to this template

> **Audience.** Anyone sending a change *back* to this repo — external
> contributors and AI sessions working on the template itself alike. For
> copying the template *into* your project, see
> [docs/ADOPTING.md](docs/ADOPTING.md) — different doc, different direction.

## Workflow

- Branch off `main`; one concern per branch/PR.
- Commit style: conventional prefix (`feat:` / `fix:` / `refactor:` / `docs:` /
  `chore:`), imperative subject ≤ 72 chars, body explaining *what* and *why*.
- **Before committing non-trivial changes**, run your code-review plugin's
  reviewer agent on the diff (see `CLAUDE.md` § Conventions) and the self-check:

  ```bash
  bash scripts/check-template.sh
  ```

- **Once pushed, never amend/force-push** — add a fixup commit instead.
  (Force-push is hard-blocked by the PreToolUse hook anyway.)
- **Stacked branches:** if branch B builds on unmerged branch A, rebase B after
  A merges *before* opening B's PR — a stale fork point shows up as phantom
  deletions of A's changes in B's diff.
- User-visible changes get an entry under `## [Unreleased]` in `CHANGELOG.md`
  (Keep a Changelog categories — one header per category per release block).
  Significant or hard-to-reverse decisions get an ADR (`/adr`).

CI (`.github/workflows/check.yml`) runs `check-template.sh` plus a gitleaks
history scan. It deliberately runs **no project build/test and holds no
secrets**, so fork PRs can't execute untrusted code against anything valuable.
Keep it that way — don't add secret-bearing steps to it.

## Repo-specific working agreements

Things that are true for *this* repo but **not** for adopter repos. An AI
session working here follows these even where the template's own docs tell
adopters to do otherwise:

- **No `/handoff` here.** `AI_CONTEXT.md` stays deliberately blank — it's the
  skeleton adopters copy. End a session by relying on git history (and
  machine-local auto-memory); don't append session blocks to `AI_CONTEXT.md`.
- **No named adopters in public docs.** Credit downstream projects
  generically ("personal projects dogfooding the template") in `README.md`,
  `CHANGELOG.md`, and ADRs.
- **Verify adopter-feedback premises before shipping.** When feedback argues
  from a perceived problem, walk through the actual semantics before agreeing
  — a plausible-sounding report has shipped a wrong "fix" before (reverted in
  the same PR).
- **Recurring-token-cost features default to opt-in.** Anything that adds
  always-on or per-prompt context cost ships *unwired*, with a documented
  enable snippet (precedents: the format-on-edit hook, the lockdown settings
  overlay, the clock heartbeat — see `docs/claude-code-setup.md`). Valuable ≠
  on-by-default. Cost classes + the per-session context tax: `docs/token-awareness.md`.

## Promote practices out of auto-memory

Working practices accumulate invisibly in machine-local auto-memory
(`~/.claude/projects/<this-repo>/memory/`) — and auto-memory doesn't travel.
That's how an adopter repo ended up with the review plugin installed but no
reviews running: the practice lived only in one machine's memory.

At session close, ask: **did any new memory encode a practice that should
travel?** Promote it to the surface that ships:

| The practice concerns | Promote into |
|-----------------------|--------------|
| How adopters' sessions should work | `CLAUDE.md` § Conventions (Bucket 1 — keep-verbatim) or a `.claude/commands/` step |
| How work on *this* repo is done | This file |
| A significant/hard-to-reverse design call | An ADR (`/adr`) |

A practice that lives only in one machine's memory is a practice the
template doesn't have.
