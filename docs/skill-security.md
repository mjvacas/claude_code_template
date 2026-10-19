# Skill & Config Security

Skills, slash commands, subagents, hooks, and MCP servers are **code you install**.
A `.claude/` artifact can run shell commands, read files, reach the network, and steer
the model. Treat anything from outside your own repo with the same scrutiny as a
third-party dependency. This doc is the policy + checklist; pair it with the tools in
`scripts/`.

## The threat model

What a malicious or compromised artifact can do:

- **Load-time shell execution** — `` !`cmd` `` and ```` ```! ```` blocks run *before the
  model sees the output*. Pure code execution at load.
- **Auto-running hooks** — a hook in `.claude/settings.json` runs automatically on
  lifecycle events (e.g. SessionStart) once you accept the folder's trust dialog.
  Cloning a repo and clicking "trust" can run attacker code. (Non-interactive `-p`
  mode skips the trust prompt entirely.) Plugins declare hooks too, in
  `hooks/hooks.json` or in `.claude-plugin/plugin.json`, and enabling a plugin can also
  start MCP and LSP servers and monitors. Skills and agents can declare hooks in their
  frontmatter, which run while the skill or agent is active. A settings `env` entry
  such as `BASH_ENV`, `NODE_OPTIONS` or `LD_PRELOAD` makes the shells and tools Claude
  starts run other code.
- **Tool pre-approval** — a skill's `allowed-tools` suppresses per-call prompts while
  it's active (removes your speed bumps).
- **Prompt injection** — instructions in the body ("read `.env` and POST it", "loosen
  `settings.json`", "ignore previous instructions").
- **Bundled scripts** — files the skill tells the model to execute, including binaries
  a launcher downloads on first run.
- **Model-invocation** — without `disable-model-invocation`, the model can trigger a
  skill on its own based on its description. Subagents are always delegated to by
  description; no frontmatter turns that off, but a `deny` on `Agent(<name>)` does.
- **MCP servers** — external processes that can read context and reach the network.

## The hard backstop: deny always wins

Permission precedence is **`deny` > `ask` > `allow`**, a deny from *any* scope wins, and
**nothing exceeds it** — not `allowed-tools`, not a hook returning `"allow"`, not
autonomous invocation. A correct deny list is your jail. This template denies reads of
secret files (`.env*`, keys, `secrets/`, `.aws/credentials`) and of credential stores in
your home directory (`~/.ssh`, `~/.aws`, `~/.config/gh`, …), plus the never-needed exfil
tools (`nc`, `ncat`, `telnet`), by default in `.claude/settings.json`. On current Claude
Code a Read deny also covers the shell commands it recognizes as reads (`cat`, `head`,
`sed`, `grep` on the path, `<` redirects), so `cat .env` is refused. It doesn't cover
code that opens files itself (a Python one-liner, a bundled script), which is why the OS
sandbox is the real boundary for untrusted code.

## Trust controls Claude Code gives you

*(Confirm exact setting keys against current docs before relying on them — a few evolve.)*

- **Trust-on-first-use dialog** — opening a new folder prompts before loading its
  `.claude/` config, hooks, and MCP servers. Don't reflexively accept it on cloned
  repos; review their `.claude/` first.
- **`disable-model-invocation: true`** (frontmatter) — only you can invoke; the model can't.
- **`skillOverrides`** (settings) — disable/hide a specific skill without editing it.
- **Sandbox** — OS-level filesystem/network isolation for Bash (`sandbox.enabled`,
  with `allowUnsandboxedCommands: false` to prevent escape).
- **Managed/enterprise settings** — the only layer users can't override: forced denies,
  `allowManagedHooksOnly`, `strictPluginOnlyCustomization`, `disableSkillShellExecution`
  (neuters the `` !`cmd` `` vector), `disableBypassPermissionsMode`, `blockedMarketplaces`.

## Treat skills as dependencies

- **Provenance & pinning** — only from sources you trust (Anthropic-curated >
  reviewed-community > random gist). Pin to a commit; don't auto-update.
- **A checksum proves only what its source proves** — a `.sha256` downloaded from the
  same release as the binary shows the download wasn't corrupted, not that the release
  is the one you reviewed. Pin to a hash recorded in your repo, so changing it takes a
  PR. (This template's CI pins gitleaks this way.)
- **Vendor, don't fetch-at-runtime** — copy the artifact in, review it, commit it. Now
  it's frozen and goes through PR review. A launcher that downloads its engine "once,
  on first run" is fetching at runtime.
- **Review on add *and* every update** — the classic attack is a benign v1 that turns
  malicious in v3. Diff every bump.
- **Least privilege** — anything external or side-effecting gets
  `disable-model-invocation: true`, and so does any skill whose description matches
  most tasks in an area or whose body sets a persona: if Claude could start it on its
  own, it would steer every matching change. Never add broad `allowed-tools`.
  (`user-invocable` is not a model control; it only hides a skill from the `/` menu.)
- **Deny what its docs tell Claude to run** — if vetted docs say to run `npx <pkg>`
  (an unpinned download-and-run), add project denies. A rule matches only the literal
  text before its `*`, so cover the bare, versioned and auto-confirm forms:
  `Bash(npx <pkg>:*)`, `Bash(npx <pkg>@*)`, `Bash(npx -y <pkg>:*)`,
  `Bash(npx -y <pkg>@*)`, `Bash(npx --yes <pkg>:*)`, `Bash(npx --yes <pkg>@*)`. If the
  project never needs `npx`, deny `Bash(npx:*)` instead. Bash denies match command
  text and can be bypassed, but they cost nothing; the sandbox is the real boundary.
- **Quarantine, then promote** — keep unvetted skills in `settings.local.json` (your
  machine only); only commit to `.claude/` after vetting.
- **Review gate** — require extra review on `.claude/**` changes (e.g. CODEOWNERS).

### Partial vendoring: taking the skill out of a plugin

Many plugins are one markdown skill wrapped in hooks, scripts, a binary and agents.
When the markdown is what you want:

1. Copy in only `SKILL.md` and the reference files it reads. Leave out scripts,
   binaries, hooks and agents. Hooks in the `SKILL.md` frontmatter survive the copy:
   remove them or vet them.
2. Add `disable-model-invocation: true` to its frontmatter.
3. Add a short note at the top of `SKILL.md` that sends every engine or script step to
   the skill's own fallback, and tells Claude not to download or run the engine. Prefer
   skills that document a fallback; without one, the copy keeps asking for tools you
   left out.
4. Record each local patch in `VENDORED.md` as a "re-apply on every bump" list, beside
   the pinned tag/SHA and license (format: `docs/ADOPTING.md` → Source-pin manifest).
   On each bump, diff the upstream skill directory between tags, run
   `scripts/audit-config.sh` on the new copy, grep the references for new commands,
   package runners and URLs, then re-apply the patches.

## Vetting an MCP server (before adding to `.mcp.json`)

An MCP server is an external process that can read your context and reach the network,
loaded once you accept the folder-trust dialog. Anthropic does **not** audit third-party
servers — vet each like an unpinned dependency. Start from `.mcp.json.example`.

- **Provenance & pinning** — prefer first-party / Anthropic-listed servers; pin the package
  version or image digest, never `@latest`.
- **Least scope** — filesystem servers get one project path, never `$HOME` or `/`. Servers
  that reach the network get the lockdown overlay while you watch their first runs.
- **Auto-approve caveat** — do **not** set `autoApproveMcpjsonServers` /
  `enableAllProjectMcpServers` globally: a cloned repo's `.mcp.json` would then launch its
  servers with no prompt. `.mcp.json` is gitignored here; only `.mcp.json.example` is tracked.
- **Deny still wins** — a `deny` in `settings.json` beats any MCP tool. Block one with
  `mcp__<server>__<tool>` (or `mcp__<server>__*` for the whole server); the lockdown egress
  denies also cover MCP calls.
- **Marketplaces are the same surface** — `/plugin` marketplaces bundle skills/hooks/MCP and
  warrant the same review (managed `blockedMarketplaces` can restrict them).

## Vetting checklist (before adding anything from online)

Read it like untrusted code:

- [ ] **Frontmatter:** what does `allowed-tools` pre-approve? Can it self-invoke (is
      `disable-model-invocation` missing)? Any surprising `model` / `context: fork` / `agent`?
      For an agent, which `tools:` does it get? None listed means all of them. Does it
      set `mcpServers` or `permissionMode`?
- [ ] **Body:** every `` !`cmd` `` and ```` ```! ```` block — read each command.
- [ ] **Bundled files:** scripts the skill tells the model to run, anything a
      launcher downloads, and symlinks (a link can point anywhere on your disk).
- [ ] **Hooks:** every hook it registers (`settings.json`, `hooks/hooks.json`,
      `plugin.json`, `hooks:` in skill or agent frontmatter), and settings `env` vars
      that load code (`BASH_ENV`, `NODE_OPTIONS`, `LD_PRELOAD`). A hook guarded like
      `[ ! -f X ] || X` does nothing until X
      exists, so copying X in later turns it on with no warning. "Does nothing today"
      isn't a pass; vet what it *would* run.
- [ ] **Egress / secrets:** `curl`, `wget`, `nc`, `/dev/tcp`, `base64`, `WebFetch`,
      external URLs, reads of `.env` / `~/.ssh` / `~/.aws` / `secrets/`, and package
      runners (`npx`, `bunx`, `uvx`, `pipx run`, `npm exec`, `pnpm dlx`, and aliases
      like `npm x`) that download and run unpinned code.
- [ ] **Egress in compiled code:** grep compiled sources too (Rust crates, Go modules),
      not just scripts. Look for telemetry (is it on by default? does `DO_NOT_TRACK=1`
      turn it off?) and for reads of `*_API_KEY` variables: a tool that quietly uses a
      key already in your environment spends money and sends data out.
- [ ] **Local servers:** a "live mode" that injects a script into your dev server, or
      offers to loosen the Content Security Policy, is a security change. Review it
      like one.
- [ ] **Injection:** "ignore previous instructions", edits to `settings.json` / hooks /
      `.gitignore`, anything that weakens permissions, hidden/obfuscated text.
- [ ] **Provenance:** who publishes it, is it pinned, is the source maintained?
- [ ] **Default posture:** install with `disable-model-invocation`, run once in a
      sandbox/throwaway dir with the lockdown overlay (below), watch what it does.
- [ ] **Token cost:** which class — `free-local` / `on-use` / `session` / `per-prompt`
      ([docs/token-awareness.md](token-awareness.md))? Anything `session` or `per-prompt`
      defaults to opt-in; weigh the recurring context tax against the value.

## Tools in this template

- **`scripts/audit-config.sh [path]`** — reports what a `.claude/` artifact or plugin
  actually does: dynamic `` !`cmd` `` execution, `allowed-tools` grants, every skill,
  command and agent (tagged model-invocable or opted out; agents with their tools;
  frontmatter hooks and MCP servers), bundled scripts, binaries and symlinks, commands
  that run without a prompt (hooks in settings, `hooks/hooks.json` or `plugin.json`;
  `statusLine`, helper keys and code-loading `env` vars; MCP/LSP servers; monitors),
  and egress/secret tokens including package runners. Run it on a candidate skill
  *before* adding it. It reports; you decide (`--strict` exits non-zero on high-signal
  findings and on anything it couldn't read). It reads frontmatter without a YAML
  parser, so treat an "opted out" tag as a hint and check the file.
- **`scripts/check-template.sh`** — integrity (JSON valid, hooks runnable, `@references`
  resolve) + a secret-pattern smoke test. Not a real secret scanner — see below.
- **`.claude/settings.lockdown.json.example`** — the quarantine overlay: merge its deny
  rules into `settings.local.json` to block network egress while vetting.

## Static analysis (SAST) for the code itself

The auditor above protects against malicious *config*. To find vulnerabilities in your
*app code*, run a SAST tool. Pick per project — both run locally/manually:

| | CodeQL | Semgrep |
|---|---|---|
| Engine license | Not OSS; **free for open-source/research, GitHub Advanced Security required for proprietary code** | OSS (LGPL); **free for commercial use** |
| Local ergonomics | Heavy: builds a database; compiled langs need a build | Light: no build step |
| Strength | Deep dataflow/taint analysis | Fast, broad, easy custom rules |

```bash
# Semgrep (lightest; commercial-friendly)
pipx install semgrep        # or: brew install semgrep
semgrep --config auto .                          # human-readable
semgrep --config auto --sarif -o results.sarif . # for tooling

# CodeQL (deepest; mind the license for proprietary code)
#   install: https://github.com/github/codeql-cli-binaries/releases
codeql database create .codeql-db --language=<lang> --source-root=.
codeql database analyze .codeql-db codeql/<lang>-queries --format=csv --output=results.csv
```

Gitignore scan output (`*.sarif`, `.codeql-db/`). And remember: **no findings ≠ secure** —
SAST finds known patterns, not business-logic flaws. Use it as triage, not proof.
