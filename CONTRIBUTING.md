# Contributing to this template

> **Audience.** Anyone sending a change *back* to this repo (external
> contributors and AI sessions working on the template itself alike). For
> copying the template *into* your project, see
> [docs/ADOPTING.md](docs/ADOPTING.md). That doc covers the other direction.

## Workflow

- Branch off `main`. One concern per branch and PR.
- Commit style: conventional prefix (`feat:`, `fix:`, `refactor:`, `docs:`,
  `chore:`), imperative subject ≤ 72 chars, body explaining *what* and *why*.
- **Before committing nontrivial changes**, run your code review plugin's
  reviewer agent on the diff (see `CLAUDE.md` § Conventions) and the self-check:

  ```bash
  bash scripts/check-template.sh
  ```

- **Once pushed, never amend or force push.** Add a fixup commit instead.
  (The PreToolUse hook hard blocks force push anyway.)
- **Stacked branches:** if branch B builds on unmerged branch A, rebase B after
  A merges *before* opening B's PR. A stale fork point shows up as phantom
  deletions of A's changes in B's diff.
- User visible changes get an entry under `## [Unreleased]` in `CHANGELOG.md`
  (Keep a Changelog categories, one header per category per release block).
  Significant or hard to reverse decisions get an ADR (`/adr`).

CI (`.github/workflows/check.yml`) runs `check-template.sh` plus a gitleaks
history scan. It deliberately runs **no project build or test and holds no
secrets**, so fork PRs can't execute untrusted code against anything valuable.
Keep it that way. Don't add steps to it that carry secrets.
`.github/workflows/template-tests.yml` runs each regression suite
(`bash tests/<suite>/run.sh`, one per tested script or hook) under the same
constraints. When you change a tested script or hook, add a case that fails
before the change and passes after.

## Working agreements for this repo

Things that are true for *this* repo but **not** for adopter repos. An AI
session working here follows these even where the template's own docs tell
adopters to do otherwise:

- **No `/handoff` here.** `AI_CONTEXT.md` stays deliberately blank. It's the
  skeleton adopters copy. End a session by relying on git history (and the
  auto memory on your machine). Don't append session blocks to `AI_CONTEXT.md`.
- **No named adopters in public docs.** Credit downstream projects
  generically ("personal projects dogfooding the template") in `README.md`,
  `CHANGELOG.md`, and ADRs.
- **Verify the premises of adopter feedback before shipping.** When feedback
  argues from a perceived problem, walk through the actual semantics before
  agreeing. A plausible sounding report has shipped a wrong "fix" before
  (reverted in the same PR).
- **Features with a recurring token cost default to opt-in.** Anything that adds
  always on or per-prompt context cost ships *unwired*, with a documented
  enable snippet (precedents: the format-on-edit hook and the clock heartbeat in
  `docs/claude-code-setup.md`, the lockdown settings overlay in
  `docs/skill-security.md`). Valuable doesn't mean on by default. Cost classes
  and the per session context tax are in `docs/token-awareness.md`.

## Promote practices out of auto memory

Working practices accumulate invisibly in the auto memory on your machine
(`~/.claude/projects/<this-repo>/memory/`). Auto memory doesn't travel.
That's how an adopter repo ended up with the review plugin installed but no
reviews running. The practice lived only in one machine's memory.

At session close, ask: **did any new memory encode a practice that should
travel?** Promote it to the surface that ships:

| The practice concerns | Promote into |
|-----------------------|--------------|
| How adopters' sessions should work | `CLAUDE.md` § Conventions (Bucket 1, keep verbatim) or a `.claude/commands/` step |
| How work on *this* repo is done | This file |
| A significant or hard to reverse design call | An ADR (`/adr`) |

A practice that lives only in one machine's memory is a practice the
template doesn't have.
