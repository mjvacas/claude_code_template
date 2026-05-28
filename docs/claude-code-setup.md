# Claude Code Setup

How this template wires into Claude Code's native features, and what to customize
after you copy it into a new project.

## What ships in `.claude/`

| Path | What it does | Customize? |
|------|--------------|-----------|
| `settings.json` | Permissions (deny secret reads, allow safe read-only commands), `defaultMode: acceptEdits`, a `SessionStart` hook. Committed, team-shared. | Yes — tune the allow list to your stack. |
| `settings.local.json` | Your personal overrides. **Gitignored.** Copy `settings.local.json.example` to start. | Personal. |
| `hooks/session-context.sh` | `SessionStart` hook: prints recent commits + working-tree status into context. Safe no-op outside git. | Optional — delete the hook entry in `settings.json` to disable. |
| `hooks/block-dangerous.sh` | `PreToolUse(Bash)` guard: hard-blocks catastrophic commands (`rm -rf /`, `git reset --hard`, `git push --force`, pipe-to-shell, `dd`/`mkfs`, fork bomb) via exit 2. A safety net, **not** a sandbox. | Tune the pattern list to your needs. |
| `hooks/precompact-snapshot.sh` | `PreCompact` hook: before the context is compacted, writes a recovery breadcrumb (transcript pointer + recent turns) to `.claude/snapshots/` (gitignored). A safety net, not a replacement for `/handoff`. | Optional — delete the hook entry in `settings.json` to disable. |
| `statusline.sh` | Status line: model · dir · git branch · context warning. | Optional — remove the `statusLine` key in `settings.json` to disable. |
| `commands/session-start.md` | `/session-start` — restore context and orient before coding. | As needed. |
| `commands/handoff.md` | `/handoff` — record decisions in `AI_CONTEXT.md` and commit code + context atomically. | As needed. |
| `commands/commit.md` | `/commit` — one atomic, conventional-prefix commit; enforces the code + `AI_CONTEXT.md` rule. | As needed. |
| `commands/adr.md` | `/adr "<title>"` — scaffold the next ADR from `templates/ADR-template.md` into `docs/adr/`. | As needed. |
| `agents/code-reviewer.md` | Subagent that reviews diffs for simplicity, scope, and duplication. | As needed. |
| `skills/verify-refactor/` | Prove a refactor preserved behavior via golden-output diff. | As needed. |
| `skills/tune-parameters/` | Pick a parameter by reading the metric surface, not the peak. | As needed. |
| `skills/llm-eval/` | Ground-truth accuracy harness for AI features. | As needed. |

> To review a diff, invoke the **`code-reviewer` subagent** ("use the code-reviewer
> subagent on my changes"). There's intentionally no `/review` command — it would just
> duplicate the subagent, which the template's own "don't duplicate" rule forbids.

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

`settings.json` denies reads of common secret files (`.env*`, `secrets/**`, keys) — these
deny rules win over any allow. The allow list pre-approves safe, read-only inspection
commands so you aren't prompted for them. Add your build/test/lint commands to the allow
list (project-shared) or to `settings.local.json` (just you), e.g.:

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
2. **`settings.json` deny rules** stop Claude from *reading* those same files; a deny
   always wins over an allow.
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

## Where the long-form guidance lives

The `.claude/` commands and skills are deliberately short and *reference* the deep
write-ups so nothing is duplicated:

- `templates/AI_SESSION_START.md` — full session onboarding + handoff procedure.
- `templates/LLM_APP_DEVELOPMENT_BEST_PRACTICES.md` — context preservation, prompting,
  architecture, testing/validation patterns.

These are loaded on demand (when a command/skill references them), not on every session,
which keeps the always-loaded context lean.
