# Claude Code Setup

How this template wires into Claude Code's native features, and what to customize
after you copy it into a new project.

## What ships in `.claude/`

| Path | What it does | Cost | Customize? |
|------|--------------|------|-----------|
| `settings.json` | Permissions (denies for secret files in the project and credential stores in `~`; asks before edits to `CLAUDE.md`, `.github/` and the check scripts; an empty allow list; `defaultMode: acceptEdits` **auto-applies other file edits without prompting**), statusline, and SessionStart/PreToolUse/PreCompact hooks. Committed, team-shared. | `free-local` | Yes — add your build/test/lint to the allow list. |
| `settings.local.json` | Your personal overrides. **Gitignored.** Copy `settings.local.json.example` to start. | `free-local` | Personal. |
| `hooks/session-context.sh` | `SessionStart` hook: prints the session-start time, recent commits + working-tree status into context. Outside git only the clock line prints. | `session` | Optional — delete the hook entry in `settings.json` to disable. |
| `hooks/clock.sh` | `UserPromptSubmit` heartbeat (**opt-in, not wired by default**): injects the current time into context on every prompt, so the session can notice elapsed time and date rollovers. | `per-prompt` | Opt-in — see [§ Optional: session clock heartbeat](#optional-session-clock-heartbeat). |
| `hooks/block-dangerous.sh` | `PreToolUse(Bash)` guard: hard-blocks catastrophic commands (`rm -rf /`, `git reset --hard`, `git push --force`, pipe-to-shell, `dd`/`mkfs`, fork bomb) via exit 2, and still blocks when `python3` is missing. A safety net, **not** a sandbox. | `free-local` | Tune the pattern list to your needs. |
| `hooks/precompact-snapshot.sh` | `PreCompact` hook: before the context is compacted, writes a recovery breadcrumb (transcript pointer + recent turns) to `.claude/snapshots/` (gitignored, owner-only, newest 20 kept). Fires on every kind of compaction, including idle. A safety net, not a replacement for `/handoff`. | `free-local` | Optional — delete the hook entry in `settings.json` to disable. |
| `statusline.sh` | Status line: model · dir · git branch, plus live session context as absolute tokens vs the window (`ctx 152k/1M`, `⚠` at ~200k), 5-hour + weekly rate-limit usage with reset clocks (`5h 24% (16:30)`/`7d 41% (Tue 16:30)`, subscription plans), and an estimated session cost `~$` (pay-as-you-go only — it's notional on a subscription, so the line hides it there and the rate-limit windows carry the real signal). | `free-local` | Optional — remove the `statusLine` key in `settings.json` to disable. |
| `commands/session-start.md` | `/session-start` — restore context and orient before coding. | `on-use` | As needed. |
| `commands/handoff.md` | `/handoff` — record decisions in `AI_CONTEXT.md` and commit code + context atomically. | `on-use` | As needed. |
| `commands/commit.md` | `/commit` — one atomic, conventional-prefix commit; enforces the code + `AI_CONTEXT.md` rule. | `on-use` | As needed. |
| `commands/adr.md` | `/adr "<title>"` — scaffold the next ADR from `templates/ADR-template.md` into `docs/adr/`. | `on-use` | As needed. |
| `skills/verify-refactor/` | Prove a refactor preserved behavior via golden-output diff. | `on-use` | As needed. |
| `skills/tune-parameters/` | Pick a parameter by reading the metric surface, not the peak. | `on-use` | As needed. |
| `skills/llm-eval/` | Ground-truth accuracy harness for AI features. | `on-use` | As needed. |

The **Cost** column uses the four classes from
[`docs/token-awareness.md`](token-awareness.md) (`free-local` / `on-use` /
`session` / `per-prompt`). Every new `.claude/` artifact gets a tag here — this
table is the canonical place, so cost stays legible without an inert frontmatter
field Claude Code wouldn't read.

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

`settings.json` denies reading common secret files (`.env*`, `secrets/**`, keys) and the
credential stores in your home directory (`~/.ssh`, `~/.aws`, `~/.config/gh`, `~/.kube`,
`~/.npmrc`, …). Deny rules win over any allow. On current Claude Code they also cover the
shell commands it recognizes as reads (`cat`, `head`, `tail`, `sed`, `grep` on a denied
path, `<` redirects), so `cat .env` is refused. They don't cover code that opens files
itself (a Python one-liner, a bundled script); for untrusted code the real boundary is the
sandbox. `Read(~/.aws/**)` also hides `~/.aws/config`, so use the CLI for tool settings
(`aws configure list`, `ssh -G <host>`, `gh auth status`).

Read-only commands (`ls`, `cat`, `grep`, `git status`, `git diff`, `git log`, …) run
without a prompt whatever the allow list says, so the template's allow list is empty;
everything else prompts unless allowed. Allow only what you'd approve every time: a broad
`Bash(git diff:*)` would also approve `git diff --output=<file>`, which writes a file. The
template also asks before edits to `CLAUDE.md`, anything under `.github/`, and
`scripts/check-template.sh` / `scripts/audit-config.sh`, which check the other protections.
Claude Code already asks before edits to `.claude/`, `.git/` and `.mcp.json`; the
template still lists its own settings, hooks and status line, so that gate doesn't depend
on a default that could change. That covers the file tools and `sed -i`, not a shell copy or redirect (`cp`,
`>>`), so treat it as a speed bump. With no one to ask (`claude -p`, `dontAsk` mode) an ask
becomes a deny. `/adr` edits `CLAUDE.md`, so it prompts once per ADR.

Add your build/test/lint commands to the allow list (project-shared) or to
`settings.local.json` (just you), e.g.:

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
2. **`settings.json` deny rules** block reading those files and the credential stores in
   `~`, through the file tools and the shell commands Claude Code recognizes as reads
   (`cat .env` is refused). Code that opens files itself isn't covered; for untrusted code
   the real boundary is the sandbox.
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

Validates JSON, hook scripts, every `@reference`, that every script `settings.json` wires
exists and the PreToolUse guard stays wired on Bash, that the referenced doc directories
exist, and the secrets protections above (including the home-directory denies and private
snapshots). Runs automatically
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
- `docs/token-awareness.md` — the cost classes behind the **Cost** column above, the
  per-session context tax, compaction (including idle compaction and how to opt out),
  and model-routing guidance. `scripts/compaction-report.sh` shows which of your
  sessions were compacted.

These are loaded on demand (when a command/skill references them), not on every session,
which keeps the always-loaded context lean.
