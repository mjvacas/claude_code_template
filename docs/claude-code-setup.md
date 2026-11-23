# Claude Code Setup

How this template wires into Claude Code's native features and what to customize
after you copy it into a new project.

## What ships in `.claude/`

| Path | What it does | Cost | Customize? |
|------|--------------|------|-----------|
| `settings.json` | Permissions, statusline, and SessionStart and PreToolUse hooks. The permissions deny secret files in the project and credential stores in `~`. They ask before `git push`, `rm`, and edits to `CLAUDE.md`, `.github/`, the check scripts and its own settings, hooks and status line. The allow list is empty. `defaultMode: acceptEdits` **applies other file edits automatically, without prompting**. Committed, shared with the team. | `free-local` | Yes. Add your build, test and lint commands to the allow list. |
| `settings.local.json` | Your personal overrides. **Gitignored.** Copy `settings.local.json.example` to start. | `free-local` | Personal. |
| `settings.lockdown.json.example` | Quarantine overlay (**not loaded**): network egress denies (`WebFetch`, `curl`, `wget`, `ssh`, …) to merge into `settings.local.json` while you vet an untrusted skill. | `free-local` | Opt-in. See [`docs/skill-security.md`](skill-security.md). |
| `hooks/session-context.sh` | `SessionStart` hook: prints the session start time, recent commits and working tree status into context, plus a reminder to archive `AI_CONTEXT.md` once it passes 1000 lines. Outside git only the clock line prints. | `session` | Optional. Delete the hook entry in `settings.json` to disable. |
| `hooks/clock.sh` | `UserPromptSubmit` heartbeat (**opt-in, unwired by default**): injects the current time into context on every prompt, so the session can notice elapsed time and date rollovers. | `per-prompt` | Opt-in. See [§ Optional: session clock heartbeat](#optional-session-clock-heartbeat). |
| `hooks/block-dangerous.sh` | `PreToolUse(Bash)` guard: blocks catastrophic commands outright (`rm -rf /`, `git reset --hard`, `git push --force`, pipe to shell, `dd` and `mkfs`, fork bomb) via exit 2 and still blocks when `python3` is missing. It's a safety net. It is **not** a sandbox. | `free-local` | Tune the pattern list to your needs. To try a pattern, save `{"tool_name":"Bash","tool_input":{"command":"<cmd>"}}` to a file with the Write tool and run `.claude/hooks/block-dangerous.sh < sample.json`. Exit 2 with a deny message means blocked (without `tool_name` the hook ignores the event). Typed inline in a Claude session, the sample command trips the live guard first. |
| `statusline.sh` | Status line: model · dir · git branch, plus live session context as absolute tokens vs the window (`ctx 152k/1M`, `⚠` at ~200k), 5 hour and weekly rate limit usage with reset clocks (`5h 24% (16:30)`/`7d 41% (Tue 16:30)`, subscription plans), and an estimated session cost `~$` on pay as you go plans only. On a subscription that cost is notional, so the line hides it there and the rate limit windows carry the real signal. | `free-local` | Optional. Remove the `statusLine` key in `settings.json` to disable. |
| `commands/session-start.md` | `/session-start`: restore context and orient before coding. | `on-use` | As needed. |
| `commands/handoff.md` | `/handoff`: record decisions in `AI_CONTEXT.md` and commit code and context atomically. | `on-use` | As needed. |
| `commands/commit.md` | `/commit`: one atomic commit with a conventional prefix. Enforces the rule to commit code and `AI_CONTEXT.md` together. | `on-use` | As needed. |
| `commands/adr.md` | `/adr "<title>"`: scaffold the next ADR from `templates/ADR-template.md` into `docs/adr/`. | `on-use` | As needed. |
| `skills/verify-refactor/` | Prove a refactor preserved behavior via a golden output diff. | `on-use` | As needed. |
| `skills/tune-parameters/` | Pick a parameter by reading the metric surface, not the peak. | `on-use` | As needed. |
| `skills/llm-eval/` | Ground truth accuracy harness for AI features. | `on-use` | As needed. |
| `skills/cc-task-bench/` | Method for benchmarking which model to route each task type to. V1 is design only: no runner yet ([ADR-003](adr/ADR-003-cc-task-bench-scope.md)). | `on-use` | Reference-only. Internal to the template. |

The **Cost** column uses the four classes from
[`docs/token-awareness.md`](token-awareness.md) (`free-local`, `on-use`,
`session`, `per-prompt`). Every new `.claude/` artifact gets a tag here. This
table is the canonical place, so cost stays legible without an inert frontmatter
field Claude Code wouldn't read.

> Code review is delegated to the **`pr-review-toolkit@claude-plugins-official`**
> baseline plugin installed during adoption (see `docs/ADOPTING.md`). This
> template no longer ships its own `code-reviewer` subagent. The plugin's
> richer specialization (silent-failure-hunter, type-design-analyzer,
> pr-test-analyzer, etc.) is maintained upstream rather than forked here.

## Hybrid memory model

Two complementary stores. Keep them from overlapping:

- **`AI_CONTEXT.md`** (in this repo, committed): *human curated* decisions, rationale,
  open questions, next steps. Loaded automatically every session via `@AI_CONTEXT.md` in
  `CLAUDE.md`. You (with `/handoff`) decide what goes here.
- **Native auto memory** (`~/.claude/projects/<project>/memory/`, local to the machine,
  on by default): patterns and build quirks Claude *learns* on its own. Loaded
  automatically. Browse or edit with `/memory`.

Rule of thumb: if a human decided it, it goes in `AI_CONTEXT.md`. If Claude noticed it,
let auto memory hold it. Don't copy one into the other.

Both of those are *deliberate* checkpoints. If a long session is compacted before you run
`/handoff`, the detail isn't gone. Claude Code keeps the full transcript in
`~/.claude/projects/` (30 days by default). Its compaction summary tells the session
where to find it. See `docs/token-awareness.md` → Compaction.

## Permissions

`settings.json` denies reading common secret files (`.env*`, `secrets/**`, keys) and the
credential stores in your home directory (`~/.ssh`, `~/.aws`, `~/.config/gh`, `~/.kube`,
`~/.npmrc`, …). Deny rules win over any allow. On current Claude Code they also cover the
shell commands it recognizes as reads (`cat`, `head`, `tail`, `sed`, `grep` on a denied
path, `<` redirects), so `cat .env` is refused. They don't cover code that opens files
itself (a Python one liner, a bundled script). For untrusted code the real boundary is the
sandbox. `Read(~/.aws/**)` also hides `~/.aws/config`, so use the CLI for tool settings
(`aws configure list`, `ssh -G <host>`, `gh auth status`).

Commands that only read (`ls`, `cat`, `grep`, `git status`, `git diff`, `git log`, …) run
without a prompt whatever the allow list says, so the template's allow list is empty.
Everything else prompts unless allowed. Allow only what you'd approve every time. A broad
`Bash(git diff:*)` would also approve `git diff --output=<file>`, which writes a file. The
template also asks before edits to `CLAUDE.md`, anything under `.github/`, and the two
scripts that check the other protections (`scripts/check-template.sh`,
`scripts/audit-config.sh`). Claude Code already asks before edits to `.claude/`, `.git/`
and `.mcp.json`. The template still lists its own settings, hooks and status line, so
that gate doesn't depend on a default that could change. These asks cover the file tools
and `sed -i`. They don't cover a shell copy or redirect (`cp`, `>>`), so treat them as a
speed bump. With no one to ask (`claude -p`, `dontAsk` mode) an ask becomes a deny.
`/adr` edits `CLAUDE.md`, so it prompts once per ADR.

What that looks like in a session:

- Claude runs `cat ~/.ssh/id_ed25519`. The call is refused and Claude is told
  `Permission to use Bash with command cat ~/.ssh/id_ed25519 has been denied.`
- Claude edits `CLAUDE.md` in `acceptEdits` mode. You get a permission prompt instead of
  a silent edit.
- Claude runs `git push --force origin main`. The guard refuses it, whatever the
  permission rules say. The session shows `PreToolUse:Bash hook error: blocked by block-dangerous.sh:
  git push --force / -f / +ref / --mirror / --prune (rewrites or deletes remote history)`.

Add your build, test and lint commands to the allow list (shared with the project) or to
`settings.local.json` (just you), e.g.:

```json
{
  "permissions": {
    "allow": ["Bash(npm run test:*)", "Bash(npm run build:*)", "Bash(npx tsc --noEmit)"]
  }
}
```

## Secrets handling

Three layers, on by default. Keep them in place (the self-check below enforces it):

1. **`.gitignore`** ignores `.env*`, `*.pem`, `*.key`, `*.p12`, `id_rsa`, `id_ed25519`,
   `.aws/credentials`, and `secrets/` so they can't be committed. Commit only
   `*.example` variants (e.g. `.env.example`).
2. **`settings.json` deny rules** block reading those files and the credential stores in
   `~`, through the file tools and the shell commands Claude Code recognizes as reads
   (`cat .env` is refused). Code that opens files itself isn't covered. For untrusted
   code the real boundary is the sandbox.
3. **`scripts/check-template.sh`** (run locally and in CI) fails if a file that looks
   like a secret gets tracked, if obvious secret material (private keys, AWS keys,
   GitHub, Slack or Google tokens) appears in tracked content, or if either protection
   above is removed.

Keep real secrets in environment variables or an untracked `.env` loaded at runtime.
Never put them in tracked files. CI also scans the full git history with
[gitleaks](https://github.com/gitleaks/gitleaks) (see below).

## Validate the template

```bash
bash scripts/check-template.sh
```

Validates JSON, hook scripts, every `@reference`, that every script `settings.json` wires
exists and the PreToolUse guard stays wired on Bash, that the referenced doc directories
exist, and the secrets protections above (including the home directory denies). Runs
automatically on push and PR via `.github/workflows/check.yml`, which also runs a
`gitleaks` secret scan over the full history and no project build or tests. On a public
repo, whatever code a fork PR changes (`check-template.sh`, or the workflow file itself)
still runs on the runner, with a read only token and no secrets. The comment at the top
of `check.yml` explains the limits.

## Optional: format-on-edit hook

Not enabled by default (it depends on your stack). To format automatically after Claude
edits files, add a `PostToolUse` hook to `settings.json` and adjust the formatter:

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

(Use `black` or `ruff`, `gofmt`, `rustfmt`, etc. for other languages.)

## Optional: session clock heartbeat

Sessions have no inherent sense of time. The date injected at session start goes
stale (midnight rollover, compaction), and the model can't notice elapsed time on
its own, so it won't think to run `date` precisely when timing matters. The
template anchors time in two places that are always on and cost nothing. The
`SessionStart` hook prints a "Session started:" line. `/handoff` and `/adr` inject
today's date at invocation rather than trusting context.

For a *live* clock, `hooks/clock.sh` ships unwired. It's a `UserPromptSubmit` hook
that injects the current time on every prompt (for elapsed session time, subtract
the session start line). It costs a few tokens per prompt, which is why it's
opt-in. To enable it, add this to `settings.json` (shared with the team) or
`settings.local.json` (just you):

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

It's most useful in long running sessions. It lets the model notice "this session is
hours old" and suggest `/handoff` before context death. It also keeps dates honest
across midnight.

## Where the detailed guidance lives

The `.claude/` commands and skills are deliberately short and *reference* the detailed
writeups so nothing is duplicated:

- `templates/AI_SESSION_START.md`: the full procedure for session onboarding and handoff.
- `.claude/skills/{verify-refactor,tune-parameters,llm-eval}/SKILL.md`: each carries
  its own inline rationale (golden output diffing, tuning parameters by the shape of the
  metric surface, ground truth accuracy harness).
- `.claude/skills/cc-task-bench/SKILL.md`: benchmark method. Its schema and pricing
  file live in `bench/`.
- `docs/token-awareness.md`: the cost classes behind the **Cost** column above, the
  per session context tax, compaction (including idle compaction and how to opt out),
  and model routing guidance. `scripts/compaction-report.sh` shows which of your
  sessions were compacted.

These are loaded on demand, when a command or skill references them. They aren't loaded
every session, which keeps the context that's always loaded lean.
