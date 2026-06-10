# Claude Code Setup

How this template wires into Claude Code's native features, and what to customize
after you copy it into a new project.

## What ships in `.claude/`

| Path | What it does | Customize? |
|------|--------------|-----------|
| `settings.json` | Permissions (Read-tool denies for secret files; a minimal shell allow-list — only `ls` + read-only `git`; `defaultMode: acceptEdits` **auto-applies file edits without prompting**), statusline, and SessionStart/PreToolUse/PreCompact hooks. Committed, team-shared. | Yes — add your build/test/lint to the allow list. |
| `settings.local.json` | Your personal overrides. **Gitignored.** Copy `settings.local.json.example` to start. | Personal. |
| `hooks/session-context.sh` | `SessionStart` hook: prints the session-start time, recent commits + working-tree status into context. Outside git only the clock line prints. | Optional — delete the hook entry in `settings.json` to disable. |
| `hooks/clock.sh` | `UserPromptSubmit` heartbeat (**opt-in, not wired by default**): injects the current time into context on every prompt, so the session can notice elapsed time and date rollovers. | Opt-in — see [§ Optional: session clock heartbeat](#optional-session-clock-heartbeat). |
| `hooks/block-dangerous.sh` | `PreToolUse(Bash)` guard: hard-blocks catastrophic commands (`rm -rf /`, `git reset --hard`, `git push --force`, pipe-to-shell, `dd`/`mkfs`, fork bomb) via exit 2. A safety net, **not** a sandbox. | Tune the pattern list to your needs. |
| `hooks/precompact-snapshot.sh` | `PreCompact` hook: before the context is compacted, writes a recovery breadcrumb (transcript pointer + recent turns) to `.claude/snapshots/` (gitignored). A safety net, not a replacement for `/handoff`. | Optional — delete the hook entry in `settings.json` to disable. |
| `statusline.sh` | Status line: model · dir · git branch · context warning. | Optional — remove the `statusLine` key in `settings.json` to disable. |
| `commands/session-start.md` | `/session-start` — restore context and orient before coding. | As needed. |
| `commands/handoff.md` | `/handoff` — record decisions in `AI_CONTEXT.md` and commit code + context atomically. | As needed. |
| `commands/commit.md` | `/commit` — one atomic, conventional-prefix commit; enforces the code + `AI_CONTEXT.md` rule. | As needed. |
| `commands/adr.md` | `/adr "<title>"` — scaffold the next ADR from `templates/ADR-template.md` into `docs/adr/`. | As needed. |
| `skills/verify-refactor/` | Prove a refactor preserved behavior via golden-output diff. | As needed. |
| `skills/tune-parameters/` | Pick a parameter by reading the metric surface, not the peak. | As needed. |
| `skills/llm-eval/` | Ground-truth accuracy harness for AI features. | As needed. |

> Code review is delegated to the **`pr-review-toolkit@claude-plugins-official`**
> baseline plugin installed during adoption (see `docs/ADOPTING.md`). This
> template no longer ships its own `code-reviewer` subagent — the plugin's
> richer specialization (silent-failure-hunter, type-design-analyzer,
> pr-test-analyzer, etc.) is maintained upstream rather than forked here.

## Hybrid memory model

Two complementary stores — keep them from overlapping:

- **`AI_CONTEXT.md`** (in this repo, committed) — *human-curated* decisions, rationale,
  open questions, next steps. Auto-loaded every session via `@AI_CONTEXT.md` in
  `CLAUDE.md`. You (with `/handoff`) decide what goes here.
- **Native auto-memory** (`~/.claude/projects/<project>/memory/`, machine-local, on by
  default) — patterns and build quirks Claude *learns* on its own. Loaded automatically.
  Browse/edit with `/memory`.

Rule of thumb: if a human decided it, it goes in `AI_CONTEXT.md`. If Claude noticed it,
let auto-memory hold it. Don't copy one into the other.

Both of those are *deliberate* checkpoints. As a backstop against losing an in-progress
session, the `PreCompact` hook (`hooks/precompact-snapshot.sh`) auto-snapshots recent turns
+ a pointer to the append-only transcript into `.claude/snapshots/` (gitignored) right
before Claude Code compacts the context. It's a recovery breadcrumb, not curated memory —
promote anything that matters into `AI_CONTEXT.md` with `/handoff`.

## Permissions

`settings.json` denies the **Read tool** from reading common secret files (`.env*`,
`secrets/**`, keys) — these deny rules win over any allow. Note this governs the Read tool,
not the shell: a `Read(.env)` deny does **not** stop `cat .env`. That's why the allow list
is intentionally minimal — only `ls` and read-only `git` — so shell readers (`cat`, `grep`,
`rg`, `find`) prompt instead of running unattended. (Bash-pattern denies for file reads are
leaky; for a hard guarantee against untrusted code, use the sandbox.) Add your build/test/
lint commands to the allow list (project-shared) or to `settings.local.json` (just you), e.g.:

```json
{
  "permissions": {
    "allow": ["Bash(npm run test:*)", "Bash(npm run build:*)", "Bash(npx tsc --noEmit)"]
  }
}
```

## Secrets handling

Three layers, on by default — keep them in place (the self-check below enforces it):

1. **`.gitignore`** ignores `.env*`, `*.pem`, `*.key`, `*.p12`, `id_rsa`/`id_ed25519`,
   `.aws/credentials`, and `secrets/` so they can't be committed. Commit only
   `*.example` variants (e.g. `.env.example`).
2. **`settings.json` deny rules** block the *Read tool* (and the dedicated file tools) from
   reading those files, and the shell allow-list omits `cat`/`grep`/`rg`/`find` so they
   can't read a secret unattended either. (Bash-pattern denies aren't airtight — for untrusted
   code the real boundary is the sandbox.)
3. **`scripts/check-template.sh`** (run locally and in CI) fails if a secret-like file
   gets tracked, if obvious secret material (private keys, AWS keys, GitHub/Slack/Google
   tokens) appears in tracked content, or if either protection above is removed.

Keep real secrets in environment variables or an untracked `.env` loaded at runtime —
never in tracked files. For deeper scanning across git history, add
[gitleaks](https://github.com/gitleaks/gitleaks) to CI.

## Validate the template

```bash
bash scripts/check-template.sh
```

Validates JSON, hook scripts, every `@reference`, that the PreToolUse guard stays wired,
the referenced doc directories exist, and the secrets protections above. Runs automatically
on push/PR via `.github/workflows/check.yml` (which also runs a `gitleaks` secret scan and
deliberately runs no project build/test, so fork PRs can't execute untrusted code).

## Optional: format-on-edit hook

Not enabled by default (it's stack-specific). To auto-format after Claude edits files,
add a `PostToolUse` hook to `settings.json` and adjust the formatter:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "npx prettier --write", "timeout": 30 }
        ]
      }
    ]
  }
}
```

(Use `black`/`ruff`, `gofmt`, `rustfmt`, etc. for other languages.)

## Optional: session clock heartbeat

Sessions have no inherent sense of time: the date injected at session start goes
stale (midnight rollover, compaction), and the model can't notice elapsed time on
its own — so it won't think to run `date` precisely when timing matters. The
template anchors time in two always-on, zero-cost places: the `SessionStart` hook
prints a "Session started:" line, and `/handoff` + `/adr` inject today's date at
invocation rather than trusting context.

For a *live* clock, `hooks/clock.sh` ships unwired: a `UserPromptSubmit` hook that
injects the current time on every prompt (elapsed session time = subtract the
session-start line). It costs a few tokens per prompt, which is why it's opt-in.
To enable, add to `settings.json` (team-shared) or `settings.local.json` (just you):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR/.claude/hooks/clock.sh\"", "timeout": 5 }
        ]
      }
    ]
  }
}
```

Most useful in long-running sessions: it lets the model notice "this session is
hours old" and suggest `/handoff` before context death, and keeps dates honest
across midnight.

## Where the long-form guidance lives

The `.claude/` commands and skills are deliberately short and *reference* the deep
write-ups so nothing is duplicated:

- `templates/AI_SESSION_START.md` — full session onboarding + handoff procedure.
- `.claude/skills/{verify-refactor,tune-parameters,llm-eval}/SKILL.md` — each carries
  its own inline rationale (golden-output diffing; surface-shape parameter tuning;
  ground-truth accuracy harness).

These are loaded on demand (when a command/skill references them), not on every session,
which keeps the always-loaded context lean.
