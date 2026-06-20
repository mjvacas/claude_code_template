# Claude Code Project Template

A starter scaffold for new projects that work well with **Claude Code**.
It pairs Claude Code's native features (`.claude/` config, commands, subagents,
skills, hooks) with a small set of engineering-discipline practices.

**Status:** v0.2.0 (beta) — versioned with SemVer against the adoption contract;
adopters pin `VENDORED.md` to a release tag, so each re-sync can answer "am I
behind / by how much / is it breaking?" See
[ADR-006](docs/adr/ADR-006-versioning-and-release-management.md) and the
[CHANGELOG](CHANGELOG.md).

## Quick start

Adoption is driven by a Claude Code session reading [`docs/ADOPTING.md`](docs/ADOPTING.md) — **not** by manual `cp -r`. The session installs baseline plugins (`security-guidance`, `pr-review-toolkit`), runs project-specific plugin and MCP-server discovery against your stack, pins the upstream release tag in `VENDORED.md` so future re-syncs are diffable, and merges `CLAUDE.md` per the three-bucket scheme rather than overwriting your existing config.

1. From inside your target repo, clone this template as a sibling:
   ```bash
   git clone https://github.com/mjvacas/claude_code_template.git ../claude_code_template
   ```
2. Open Claude Code in your target repo. Recommended: [plan mode](https://code.claude.com/docs/en/permission-modes#analyze-before-you-edit-with-plan-mode) — the procedure has a natural read-and-decide phase before any writes.
3. Paste one of these prompts:

   **New repo (or near-empty):**
   > Read `../claude_code_template/docs/ADOPTING.md` and adopt this template into the current repo. **New project.** Follow the new-repo procedure.

   **Existing repo (Claude Code already in use):**
   > Read `../claude_code_template/docs/ADOPTING.md` and adopt this template into the current repo. **Existing project** — already has its own Claude Code config / `CLAUDE.md` / etc. Follow the existing-repo procedure.

The session handles the rest: release-tag pin, file-map traversal, plugin install + `/reload-plugins` prompt, MCP discovery, conflict resolution, `bash scripts/check-template.sh` validation, and one atomic adoption commit. Full procedure (file map, discovery rubric, re-sync flow) lives in [`docs/ADOPTING.md`](docs/ADOPTING.md).

## Layout

```
CLAUDE.md                     # Project rules + conventions (auto-loaded every session)
AI_CONTEXT.md                 # Human-curated decision log (auto-loaded via @import)
LICENSE                       # MIT
SECURITY.md                   # How to report vulns; points at the AI-config trust model
CONTRIBUTING.md               # Sending fixes back + this repo's working agreements
.editorconfig                 # Universal, stack-neutral whitespace/EOL rules
.gitignore                    # Ignores Claude-local files, secrets/env, .mcp.json, scan output
.mcp.json.example             # Vetted-server template; copy to .mcp.json (gitignored) after review
.github/workflows/check.yml   # CI: runs check-template.sh + gitleaks (no project build/test)
.claude/
├── settings.json             # Permissions, statusline, SessionStart + PreToolUse + PreCompact hooks
├── settings.local.json.example
├── settings.lockdown.json.example  # Opt-in egress denies for vetting untrusted skills
├── statusline.sh             # Status line: model · dir · branch · cost · context (tokens vs window) · 5h/7d limits + resets
├── hooks/session-context.sh  # Prints session-start time + recent git activity at session start
├── hooks/block-dangerous.sh  # PreToolUse guard: hard-blocks catastrophic shell commands
├── hooks/precompact-snapshot.sh  # PreCompact: snapshots context to .claude/snapshots/ before compaction
├── hooks/clock.sh            # Opt-in per-prompt time heartbeat (not wired by default)
├── commands/                 # /session-start, /handoff, /commit, /adr
└── skills/                   # verify-refactor, tune-parameters, llm-eval
scripts/
├── check-template.sh         # Integrity + secrets smoke-test (run manually + in CI)
└── audit-config.sh           # Reports what .claude/ artifacts do — vet skills before trusting
docs/
├── ADOPTING.md               # Adoption + re-sync procedure (the session reads this to adopt)
├── claude-code-setup.md      # How the native config is wired; what to customize
├── skill-security.md         # Trust model, vetting checklist (incl. MCP), SAST options
├── token-awareness.md        # Cost classes, per-session context tax, model-routing heuristic
├── adr/                      # Filled-in Architecture Decision Records (scaffold with /adr)
└── summaries/                # Monthly compressed recaps (YYYY-MM.md)
templates/                    # Reference docs + blank templates (loaded on demand)
├── ADR-template.md           # Copy into docs/adr/ when recording a decision
├── PROJECT_SPEC.md / ARCHITECTURE.md / BUILD_PLAN.md   # source-of-truth triad
└── AI_SESSION_START.md
```

## Hybrid memory model

Two complementary stores, kept from overlapping:

- **`AI_CONTEXT.md`** (committed) — decisions a *human* made and why. Updated via `/handoff`.
- **Native auto-memory** (`~/.claude/...`, machine-local, on by default) — patterns Claude *learns* on its own. Browse with `/memory`.

If a human decided it, it goes in `AI_CONTEXT.md`. If Claude noticed it, let auto-memory hold it.

## Security

Skills, commands, hooks, and MCP servers are code you install. Before adding anything
from outside this repo, vet it — see `docs/skill-security.md`. Quick tools:

- `bash scripts/audit-config.sh <path>` — report what a skill/config actually does
  (dynamic execution, tool grants, egress/secret tokens) before you trust it.
- `bash scripts/check-template.sh` — validate config integrity + secrets hygiene.
- The default `settings.json` denies the Read tool from secret files and keeps the shell
  allow-list minimal (so `cat .env` prompts rather than running unattended);
  `settings.lockdown.json.example` adds network-egress denies for quarantining untrusted skills.
- A `PreToolUse` hook (`.claude/hooks/block-dangerous.sh`) hard-blocks catastrophic shell
  commands (`rm -rf /`, `git reset --hard`, `git push --force`, pipe-to-shell, `dd`/`mkfs`).
  It's a safety net, **not** a sandbox — pair it with the lockdown overlay / OS sandbox.
- Before enabling an MCP server, vet it and copy `.mcp.json.example` → `.mcp.json`
  (gitignored). See the MCP checklist in `docs/skill-security.md`.

## What's distinctive here

Beyond standard scaffolding, this template encodes a few hard-won engineering
practices — as runnable skills, a cost-legibility layer, and reviewer rules:

- **`/verify-refactor`** — prove a refactor preserved behavior by diffing deterministic output (byte-identical), not just "tests pass."
- **`/tune-parameters`** — pick a threshold by reading the *shape* of the metric surface, rejecting overfit spikes.
- **`/llm-eval`** — gate AI features on accuracy against a ground-truth set.
- **Token-cost legibility** — a cost-class model (`docs/token-awareness.md`) plus a status line that surfaces live session cost, context-against-window, and 5h/7d rate-limit budgets with reset times — so the cost of the context system is visible, not guessed.

For code review, the template recommends installing
`pr-review-toolkit@claude-plugins-official` as a baseline plugin during
adoption (see `docs/ADOPTING.md`) rather than shipping a competing agent.

See `docs/claude-code-setup.md` for the full tour.

## Acknowledgements

This template builds on patterns and ideas from a number of projects and
standards.

- **Anthropic Claude Code** — the platform this template extends; settings,
  hooks, commands, agents, and skills follow its conventions.
- **[multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)**
  — Andrej Karpathy's engineering-discipline practices; the behavioral
  guidelines in `CLAUDE.md` (think-before-coding, simplicity-first,
  surgical-changes, goal-driven-execution) trace to this collection.
- **[Keep a Changelog](https://keepachangelog.com)** — the `CHANGELOG.md`
  format (Keep a Changelog + SemVer as of v0.1.0; see
  [ADR-006](docs/adr/ADR-006-versioning-and-release-management.md)).
- **Security posture standards** — specific patterns trace to specific sources:
  - **Deny-list (Read + Bash)** in `.claude/settings.json`:
    [OWASP Top 10 Proactive Controls — C5 "Secure by Default"](https://top10proactive.owasp.org/the-top-10/c5-secure-by-default/).
    The "deny by default, allowlist what's needed" principle; the deny
    entries cannot be overridden by the model.
  - **`chmod 600` enforcement** (asserted by `scripts/check-template.sh`
    section 4):
    [CIS Distribution Independent Linux Benchmark §5.3.2 (SSH Private Host
    Key File Permissions)](https://www.tenable.com/audits/items/CIS_Amazon_Linux_2_v2.0.0_L1.audit:078b3bdba9f168f66df57226c9ac50df).
    Extends CIS's `0600` mandate for SSH keys to all 13 local
    secret-bearing patterns (`.env`, `*.pem`, `*.key`, `id_rsa`, etc.).
  - **Cryptographic key handling:**
    [NIST SP 800-57 Part 1 Rev. 5 (Key Management)](https://csrc.nist.gov/pubs/sp/800/57/pt1/r5/final).
    Protection-of-keys principle informing both the Read-deny on key
    files and the `chmod 600` enforcement.
  - **Dangerous-command guard** (`.claude/hooks/block-dangerous.sh`):
    general defense-in-depth. No canonical standard mandates the specific
    regex patterns; the guard is operational hardening, documented in
    this repo as "a safety net, not a sandbox."
- **[Architecture Decision Records](https://adr.github.io/)** — Michael
  Nygard's ADR concept; `templates/ADR-template.md` follows the standard
  Status / Context / Decision / Consequences / Alternatives shape.

Real-world feedback:

- **Personal projects dogfooding the template** — adoption reviews
  surfaced the issues that drove the security-hardening series
  (PRs #3–#6) and the adoption infrastructure (`docs/ADOPTING.md` +
  `VENDORED.md`).

## Related templates

Other Claude Code template projects worth knowing about. Reviewed during
this template's design — for comparison, not borrowed from. If a deeper
adoption review surfaces specific patterns worth incorporating, those
will be credited under Acknowledgements at that time.

- **[scotthavird/claude-code-template](https://github.com/scotthavird/claude-code-template)**
  — functional-category approach (slash commands, skills, hooks, CI/CD)
  with feature counts; bias toward wholesale fork.
- **[davila7/claude-code-templates](https://github.com/davila7/claude-code-templates)**
  — NPM CLI installer + web dashboard for component discovery; selective
  adoption via `--agent`, `--command`, `--mcp` flags.
