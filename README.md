# Claude Code Project Template

A starter scaffold for **Claude Code** projects.
It pairs Claude Code's native features (`.claude/` config, commands, subagents,
skills, hooks) with a small set of engineering discipline practices.

**Status:** v0.3.1 (beta), versioned with SemVer against the adoption contract.
Adopters pin `VENDORED.md` to a release tag, so each re-sync can answer "am I
behind, by how much, and is it breaking?" See
[ADR-006](docs/adr/ADR-006-versioning-and-release-management.md) and the
[CHANGELOG](CHANGELOG.md).

## Quick start

A Claude Code session reading [`docs/ADOPTING.md`](docs/ADOPTING.md) drives adoption, **not** a manual `cp -r`. The session installs baseline plugins (`security-guidance`, `pr-review-toolkit`), runs project specific plugin and MCP server discovery against your stack, pins the upstream release tag in `VENDORED.md` so future re-syncs are diffable, and merges `CLAUDE.md` per the [three bucket scheme](docs/ADOPTING.md#merging-the-templates-claudemd) rather than overwriting your existing config.

1. From inside your target repo, clone this template as a sibling, pinned to the
   latest release tag (newest at [tags](https://github.com/mjvacas/claude_code_template/tags)):
   ```bash
   git clone --branch v0.3.1 https://github.com/mjvacas/claude_code_template.git ../claude_code_template
   ```
2. Open Claude Code in your target repo. Recommended: [plan mode](https://code.claude.com/docs/en/permission-modes#analyze-before-you-edit-with-plan-mode). The procedure has a natural phase of reading and deciding before any writes.
3. Paste one of these prompts:

   **New repo (or nearly empty):**
   > Read `../claude_code_template/docs/ADOPTING.md` and adopt this template into the current repo. **New project.** Tech stack: `<fill in>`. Follow the new-repo procedure.

   **Existing repo (Claude Code already in use):**
   > Read `../claude_code_template/docs/ADOPTING.md` and adopt this template into the current repo. **Existing project** — already has its own Claude Code config / `CLAUDE.md` / etc. Follow the existing-repo procedure.

The session handles the rest: release tag pin, file map traversal, plugin install and the `/reload-plugins` prompt, MCP discovery, conflict resolution, `bash scripts/check-template.sh` validation, and one atomic adoption commit. Full procedure (file map, discovery rubric, re-sync flow) lives in [`docs/ADOPTING.md`](docs/ADOPTING.md).

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
.github/workflows/template-tests.yml  # CI: regression tests for the template's scripts and hooks (template-internal)
.github/CODEOWNERS            # Owner review for agent config, CI, the checks and memory files
.claude/
├── settings.json             # Permissions, statusline, SessionStart + PreToolUse hooks
├── settings.local.json.example
├── settings.lockdown.json.example  # Opt-in egress denies for vetting untrusted skills
├── statusline.sh             # Status line: model · dir · branch · cost · context (tokens vs window) · 5h/7d limits + resets
├── hooks/session-context.sh  # At session start: time, recent git activity, AI_CONTEXT.md archive reminder
├── hooks/block-dangerous.sh  # PreToolUse guard: hard-blocks catastrophic shell commands
├── hooks/clock.sh            # Opt-in per-prompt time heartbeat (not wired by default)
├── commands/                 # /session-start, /handoff, /commit, /adr
└── skills/                   # verify-refactor, tune-parameters, llm-eval, cc-task-bench (design only)
scripts/
├── check-template.sh         # Integrity + secrets smoke-test (run manually + in CI)
├── audit-config.sh           # Reports what .claude/ artifacts and plugins do — vet before trusting
└── compaction-report.sh      # Lists your recent compactions and which were idle (reads ~/.claude)
tests/                        # Regression tests for the scripts and hooks (template-internal)
bench/                        # cc-task-bench schema and pricing file (template-internal)
docs/
├── ADOPTING.md               # Adoption + re-sync procedure (the session reads this to adopt)
├── claude-code-setup.md      # How the native config is wired; what to customize
├── skill-security.md         # Trust model, vetting checklist (incl. MCP), SAST options
├── token-awareness.md        # Cost classes, context tax, compaction, model-routing heuristic
├── adr/                      # Filled-in Architecture Decision Records (scaffold with /adr)
└── summaries/                # Monthly compressed recaps (YYYY-MM.md)
templates/                    # Reference docs + blank templates (loaded on demand)
├── ADR-template.md           # Copy into docs/adr/ when recording a decision
├── PROJECT_SPEC.md / ARCHITECTURE.md / BUILD_PLAN.md   # source-of-truth triad
└── AI_SESSION_START.md
```

## Hybrid memory model

Two complementary stores, kept from overlapping:

- **`AI_CONTEXT.md`** (committed): decisions a *human* made and why. Updated via `/handoff`.
- **Native auto memory** (`~/.claude/...`, local to your machine, on by default): patterns Claude *learns* on its own. Browse with `/memory`.

If a human decided it, it goes in `AI_CONTEXT.md`. If Claude noticed it, let auto memory hold it.

## Security

Skills, commands, hooks, and MCP servers are code you install. Before adding anything
from outside this repo, vet it (see `docs/skill-security.md`). Quick tools:

- `bash scripts/audit-config.sh <path>`: report what a skill, plugin or config actually
  does before you trust it. It lists every command that runs without a prompt (hooks, MCP
  and LSP servers, monitors, env vars that load code), permission grants, which skills and
  agents Claude can start on its own, and egress and secret tokens.
- `bash scripts/check-template.sh`: validate config integrity and secrets hygiene.
- The default `settings.json` denies reads of secret files in the project and of credential
  stores in your home directory (`~/.ssh`, `~/.aws`, `~/.config/gh`, …). On current Claude
  Code that covers shell reads too, so `cat .env` is refused. It asks before `git push`,
  `rm`, and edits to `CLAUDE.md`, `.github/`, the two check scripts and its own settings,
  hooks and status line. It ships an empty allow list.
  `settings.lockdown.json.example` adds network egress denies for quarantining untrusted skills.
- A `PreToolUse` hook (`.claude/hooks/block-dangerous.sh`) hard blocks catastrophic shell
  commands (`rm -rf /`, `git reset --hard`, `git push --force`, pipe to shell, `dd`, `mkfs`).
  It keeps working without `python3` and has a regression suite. It's a safety net. It is
  **not** a sandbox, so pair it with the lockdown overlay or an OS sandbox. See
  [what a refusal looks like](docs/claude-code-setup.md#permissions).
- Before enabling an MCP server, vet it and copy `.mcp.json.example` → `.mcp.json`
  (gitignored). See the MCP checklist in `docs/skill-security.md`.

## Highlights

A few engineering practices, encoded as runnable skills and scripts, a
cost legibility layer, and reviewer rules:

- **Vet before you install.** `scripts/audit-config.sh` reports everything a skill or plugin would run or grant. `docs/skill-security.md` shows how to take just the skill out of a plugin and deny what its docs tell Claude to run. For a sample documentation plugin it shows a download script that runs at every session start, an unpinned `npx` MCP server, a skill Claude can start on its own with Bash preapproved, and an agent that gets every tool ([example report](docs/skill-security.md#example-what-the-auditor-shows)).
- **`/verify-refactor`**: prove a refactor preserved behavior by diffing deterministic output (byte identical), a stronger check than "tests pass."
- **`/tune-parameters`**: pick a threshold by reading the *shape* of the metric surface, rejecting overfit spikes.
- **`/llm-eval`**: gate AI features on accuracy against a ground truth set.
- **Token cost legibility.** A cost class model (`docs/token-awareness.md`) plus a status line that surfaces live session cost, context against the window, and 5h/7d rate limit budgets with reset times. You can see what the context system costs instead of guessing.
- **Compaction you can see.** `scripts/compaction-report.sh` lists which of your sessions were compacted, how large they were and how long they'd sat idle. `docs/token-awareness.md` explains idle compaction and how to opt out. If sessions on a 1M window compact at 200K to 300K tokens about 54 minutes after your last message, that's idle compaction. You haven't hit the context limit ([example](docs/token-awareness.md#compaction)).

For code review, the template recommends installing
`pr-review-toolkit@claude-plugins-official` as a baseline plugin during
adoption (see `docs/ADOPTING.md`) rather than shipping a competing agent.

See `docs/claude-code-setup.md` for the full tour.

## Acknowledgements

This template builds on patterns and ideas from a number of projects and
standards.

- **Anthropic Claude Code**: the platform this template extends. Settings,
  hooks, commands, agents, and skills follow its conventions. Its
  [documentation](https://code.claude.com/docs) on permissions, protected paths
  and compaction shaped the v0.3.0 defaults and the idle compaction notes.
- **[Agent Baseline](https://agentbaseline.org)**: the v0.3.0 security review
  checked the template against its reference architecture,
  [*The Secure Software Factory*](https://agentbaseline.org/software-factory.pdf)
  (version 1, October 2026). Three of its points shaped the v0.3.0 defaults, and
  later releases may adopt more of the paper:
  - *Only enforced rules are boundaries.* The paper counts access, action and
    network rules and the sandbox as boundaries. It says context files and hooks
    guide the agent without constraining it. So the new credential denies
    and edit asks are permission rules in `settings.json`, which Claude Code
    enforces.
  - *A local agent runs with the developer's own access.* Claude can read the
    credentials in your home directory unless something stops it, so v0.3.0 denies
    reads of those stores (`~/.ssh`, `~/.aws`, `~/.config/gh`, …).
  - *The profile is the agent's whole setup.* The paper's profile is an agent's
    context, skills, hooks and rules, versioned as one artifact. Claude can edit
    its own profile here, so v0.3.0 makes it ask before editing `CLAUDE.md`,
    settings, hooks, status line, CI config and the template's own checks.
- **[trailofbits/claude-code-config](https://github.com/trailofbits/claude-code-config)**:
  the list of home directory credential stores to deny. Ideas only. The repo
  has no license and nothing is copied.
- **[zizmor](https://github.com/zizmorcore/zizmor)**: its "artipacked" audit is
  why CI checkouts don't keep credentials on disk.
- **[multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)**:
  Andrej Karpathy's engineering discipline practices. The behavioral
  guidelines in `CLAUDE.md` (Think Before Coding, Simplicity First,
  Surgical Changes, Goal-Driven Execution) trace to this collection.
- **[Keep a Changelog](https://keepachangelog.com)**: the `CHANGELOG.md`
  format (Keep a Changelog and SemVer as of v0.1.0, see
  [ADR-006](docs/adr/ADR-006-versioning-and-release-management.md)).
- **Security posture standards.** Specific patterns trace to specific sources:
  - **Deny list (Read and Bash)** in `.claude/settings.json`:
    [OWASP Top 10 Proactive Controls — C5 "Secure by Default"](https://top10proactive.owasp.org/the-top-10/c5-secure-by-default/).
    The "deny by default, allowlist what's needed" principle. The model
    can't override the deny entries.
  - **`chmod 600` enforcement** (asserted by `scripts/check-template.sh`
    section 4):
    [CIS Distribution Independent Linux Benchmark §5.3.2 (SSH Private Host
    Key File Permissions)](https://www.tenable.com/audits/items/CIS_Amazon_Linux_2_v2.0.0_L1.audit:078b3bdba9f168f66df57226c9ac50df).
    Extends CIS's `0600` mandate for SSH keys to local files that hold
    secrets (`.env`, `*.pem`, `*.key`, `id_rsa`, etc.).
  - **Cryptographic key handling:**
    [NIST SP 800-57 Part 1 Rev. 5 (Key Management)](https://csrc.nist.gov/pubs/sp/800/57/pt1/r5/final).
    Its key protection principle informs both the Read deny on key
    files and the `chmod 600` enforcement.
  - **Dangerous command guard** (`.claude/hooks/block-dangerous.sh`):
    general defense in depth. No canonical standard mandates the specific
    regex patterns. The guard is operational hardening. This repo
    documents it as a safety net. It isn't a sandbox.
- **[Architecture Decision Records](https://adr.github.io/)**: Michael
  Nygard's ADR concept. `templates/ADR-template.md` follows the standard
  shape: Status, Context, Decision, Consequences, Alternatives.

## Related templates

Other Claude Code template projects worth knowing about. Reviewed during
this template's design for comparison. Nothing is borrowed from them. If a
deeper adoption review surfaces specific patterns worth incorporating, those
will be credited under Acknowledgements at that time.

- **[scotthavird/claude-code-template](https://github.com/scotthavird/claude-code-template)**:
  functional category approach (slash commands, skills, hooks, CI/CD)
  with feature counts. Leans toward a wholesale fork.
- **[davila7/claude-code-templates](https://github.com/davila7/claude-code-templates)**:
  NPM CLI installer and web dashboard for component discovery. Selective
  adoption via `--agent`, `--command`, `--mcp` flags.

---

More about this template: [ventureforward.ai/projects/claude-code-template](https://ventureforward.ai/projects/claude-code-template/) · built by Mauricio Vacas
