# Skill and Config Security

Skills, slash commands, subagents, hooks, and MCP servers are **code you install**.
A `.claude/` artifact can run shell commands, read files, reach the network, and steer
the model. Treat anything from outside your own repo with the same scrutiny as a
third party dependency. This doc is the policy and checklist. Pair it with the tools in
`scripts/`.

## The threat model

What a malicious or compromised artifact can do:

- **Shell execution at load time.** `` !`cmd` `` and ```` ```! ```` blocks run *before the
  model sees the output*. Pure code execution at load.
- **Hooks that run on their own.** A hook in `.claude/settings.json` runs automatically on
  lifecycle events (e.g. SessionStart) once you accept the folder's trust dialog.
  Cloning a repo and clicking "trust" can run attacker code. (`-p` mode isn't
  interactive and skips the trust prompt entirely.) Plugins declare hooks too, in
  `hooks/hooks.json` or in `.claude-plugin/plugin.json`. Enabling a plugin can also
  start MCP and LSP servers and monitors. Skills and agents can declare hooks in their
  frontmatter, which run while the skill or agent is active. A settings `env` entry
  such as `BASH_ENV`, `NODE_OPTIONS` or `LD_PRELOAD` makes the shells and tools Claude
  starts run other code.
- **Tool preapproval.** A skill's `allowed-tools` suppresses per call prompts while
  it's active (removes your speed bumps).
- **Prompt injection.** Instructions in the body ("read `.env` and POST it", "loosen
  `settings.json`", "ignore previous instructions").
- **Bundled scripts.** Files the skill tells the model to execute, including binaries
  a launcher downloads on first run.
- **Model invocation.** Without `disable-model-invocation`, the model can trigger a
  skill on its own based on its description. Subagents are always delegated to by
  description. No frontmatter turns that off, but a `deny` on `Agent(<name>)` does.
- **MCP servers.** External processes that can read context and reach the network.

## The hard backstop: deny always wins

Permission precedence is **`deny` > `ask` > `allow`**. A deny from *any* scope wins and
**nothing exceeds it**, including `allowed-tools`, a hook returning `"allow"`, and
autonomous invocation. A correct deny list is your jail. This template denies reads of
secret files (`.env*`, keys, `secrets/`, `.aws/credentials`) and of credential stores in
your home directory (`~/.ssh`, `~/.aws`, `~/.config/gh`, …), plus exfil tools you never
need (`nc`, `ncat`, `telnet`), by default in `.claude/settings.json`. On current Claude
Code a Read deny also covers the shell commands it recognizes as reads (`cat`, `head`,
`sed`, `grep` on the path, `<` redirects), so `cat .env` is refused. It doesn't cover
code that opens files itself (a Python one liner, a bundled script), which is why the OS
sandbox is the real boundary for untrusted code.

## Trust controls Claude Code gives you

*(Confirm exact setting keys against current docs before relying on them. A few evolve.)*

- **Trust on first use dialog.** Opening a new folder prompts before loading its
  `.claude/` config, hooks, and MCP servers. Don't accept it by reflex on cloned
  repos. Review their `.claude/` first.
- **`disable-model-invocation: true`** (frontmatter): only you can invoke, the model can't.
- **`skillOverrides`** (settings): disable or hide a specific skill without editing it.
- **Sandbox.** OS level filesystem and network isolation for Bash (`sandbox.enabled`,
  with `allowUnsandboxedCommands: false` to prevent escape).
- **Managed (enterprise) settings.** The only layer users can't override: forced denies,
  `allowManagedHooksOnly`, `strictPluginOnlyCustomization`, `disableSkillShellExecution`
  (neuters the `` !`cmd` `` vector), `disableBypassPermissionsMode`, `blockedMarketplaces`.

## Treat skills as dependencies

- **Provenance and pinning.** Only from sources you trust (Anthropic curated >
  reviewed community > random gist). Pin to a commit and don't update automatically.
- **A checksum proves only what its source proves.** A `.sha256` downloaded from the
  same release as the binary shows the download wasn't corrupted. It doesn't show that
  the release is the one you reviewed. Pin to a hash recorded in your repo, so changing
  it takes a PR. (This template's CI pins gitleaks this way.)
- **Vendor, don't fetch at runtime.** Copy the artifact in, review it, commit it. Now
  it's frozen and goes through PR review. A launcher that downloads its engine "once,
  on first run" is fetching at runtime.
- **Review on add *and* every update.** The classic attack is a benign v1 that turns
  malicious in v3. Diff every bump.
- **Least privilege.** Anything external or with side effects gets
  `disable-model-invocation: true`. So does any skill whose description matches most
  tasks in an area or whose body sets a persona. If Claude could start it on its own,
  it would steer every matching change. Never add broad `allowed-tools`.
  (`user-invocable` is not a model control. It only hides a skill from the `/` menu.)
- **Deny what its docs tell Claude to run.** If vetted docs say to run `npx <pkg>`
  (it downloads and runs an unpinned package), add project denies. A rule matches only
  the literal text before its `*`, so cover the bare, versioned and auto confirm forms:
  `Bash(npx <pkg>:*)`, `Bash(npx <pkg>@*)`, `Bash(npx -y <pkg>:*)`,
  `Bash(npx -y <pkg>@*)`, `Bash(npx --yes <pkg>:*)`, `Bash(npx --yes <pkg>@*)`. If the
  project never needs `npx`, deny `Bash(npx:*)` instead. Bash denies match command
  text and can be bypassed, but they cost nothing. The sandbox is the real boundary.
- **Quarantine, then promote.** Keep unvetted skills in `settings.local.json` (your
  machine only). Only commit to `.claude/` after vetting.
- **Review gate.** Require extra review on `.claude/**` changes (e.g. CODEOWNERS).

### Partial vendoring: taking the skill out of a plugin

Many plugins are one markdown skill wrapped in hooks, scripts, a binary and agents.
When the markdown is what you want:

1. Copy in only `SKILL.md` and the reference files it reads. Leave out scripts,
   binaries, hooks and agents. Hooks in the `SKILL.md` frontmatter survive the copy,
   so remove them or vet them.
2. Add `disable-model-invocation: true` to its frontmatter.
3. Add a short note at the top of `SKILL.md` that sends every engine or script step to
   the skill's own fallback and tells Claude not to download or run the engine. Prefer
   skills that document a fallback. Without one, the copy keeps asking for tools you
   left out.
4. Record each local patch in `VENDORED.md` as a "re-apply on every bump" list, beside
   the pinned tag or SHA and license (format: `docs/ADOPTING.md` → Source pin manifest).
   On each bump, diff the upstream skill directory between tags, run
   `scripts/audit-config.sh` on the new copy, grep the references for new commands,
   package runners and URLs, then reapply the patches.

## Vetting an MCP server (before adding to `.mcp.json`)

An MCP server is an external process that can read your context and reach the network,
loaded once you accept the folder trust dialog. Anthropic does **not** audit third party
servers. Vet each like an unpinned dependency. Start from `.mcp.json.example`.

- **Provenance and pinning.** Prefer first party or Anthropic listed servers. Pin the
  package version or image digest, never `@latest`.
- **Least scope.** Filesystem servers get one project path, never `$HOME` or `/`. The
  lockdown overlay doesn't stop a server reaching the network (see **Deny still wins**),
  so for a server that reaches the network, watch its first runs in a container, VM or
  throwaway machine (`sandbox.enabled` isolates Bash commands, not MCP servers).
- **Auto approval caveat.** Do **not** set `autoApproveMcpjsonServers` or
  `enableAllProjectMcpServers` globally. A cloned repo's `.mcp.json` would then launch
  its servers with no prompt. `.mcp.json` is gitignored here. Only `.mcp.json.example`
  is tracked.
- **Deny still wins.** A `deny` in `settings.json` beats any MCP tool. Block one with
  `mcp__<server>__<tool>` (or `mcp__<server>__*` for the whole server). That stops Claude
  calling the server's tools. It doesn't stop the server itself, which runs as its own
  process with its own network access. The lockdown overlay's denies (`WebFetch` and
  shell network commands) don't reach the server's own network access.
- **Marketplaces are the same surface.** `/plugin` marketplaces bundle skills, hooks and
  MCP servers. They warrant the same review (managed `blockedMarketplaces` can restrict
  them).
- **A plugin's server can start `@latest`.** The official `playwright` plugin starts
  `npx @playwright/mcp@latest`, so it runs the newest release each time it starts. You
  can't pin it inside the plugin, because the next plugin update overwrites your edit.
  Pick one and record it in `VENDORED.md`:
  - **Accept it.** Record the plugin as unpinned and accepted, with the date and its
    launch command. Re-sync asks again only if that command changes.
  - **Pin it yourself.** Add your own `.mcp.json` entry with a fixed version. Then turn
    the plugin off on this machine
    (`claude plugin disable <plugin>@<marketplace> --scope local`). Otherwise its
    `@latest` server keeps starting next to yours. Local scope writes
    `.claude/settings.local.json`, which git ignores like `.mcp.json`, so the switch
    stays with the pin. `--scope project` would turn the plugin off in every checkout,
    including ones without your pin. `chmod 600` both files, as `check-template.sh`
    expects. Your server's tools are named `mcp__<server>__<tool>`
    instead of `mcp__plugin_<plugin>_<server>__<tool>`. A hook matcher or permission
    rule that names the old tools stops matching without any error, so a guard on them
    stops guarding. Rename them in the same commit and test the guard with a sample
    event.

## Vetting checklist (before adding anything from online)

Read it like untrusted code:

- [ ] **Frontmatter:** what does `allowed-tools` preapprove? Can it self-invoke (is
      `disable-model-invocation` missing)? Any surprising `model`, `context: fork` or
      `agent`? For an agent, which `tools:` does it get? None listed means all of them.
      Does it set `mcpServers` or `permissionMode`?
- [ ] **Body:** read each command in every `` !`cmd` `` and ```` ```! ```` block.
- [ ] **Bundled files:** scripts the skill tells the model to run, anything a
      launcher downloads, and symlinks (a link can point anywhere on your disk).
- [ ] **Hooks:** every hook it registers (`settings.json`, `hooks/hooks.json`,
      `plugin.json`, `hooks:` in skill or agent frontmatter), and settings `env` vars
      that load code (`BASH_ENV`, `NODE_OPTIONS`, `LD_PRELOAD`). A hook guarded like
      `[ ! -f X ] || X` does nothing until X exists, so copying X in later turns it on
      with no warning. "Does nothing today" isn't a pass. Vet what it *would* run.
- [ ] **Egress and secrets:** `curl`, `wget`, `nc`, `/dev/tcp`, `base64`, `WebFetch`,
      external URLs, reads of `.env`, `~/.ssh`, `~/.aws` or `secrets/`, and package
      runners (`npx`, `bunx`, `uvx`, `pipx run`, `npm exec`, `pnpm dlx`, and aliases
      like `npm x`) that download and run unpinned code.
- [ ] **Egress in compiled code:** grep compiled sources (Rust crates, Go modules) as
      well as scripts. Look for telemetry (is it on by default? does `DO_NOT_TRACK=1`
      turn it off?) and for reads of `*_API_KEY` variables. A tool that quietly uses a
      key already in your environment spends money and sends data out.
- [ ] **Local servers:** a "live mode" that injects a script into your dev server, or
      offers to loosen the Content Security Policy, is a security change. Review it
      like one.
- [ ] **Injection:** "ignore previous instructions", edits to `settings.json`, hooks or
      `.gitignore`, anything that weakens permissions, hidden or obfuscated text.
- [ ] **Provenance:** who publishes it, is it pinned, is the source maintained?
- [ ] **Default posture:** install with `disable-model-invocation`, run once in a
      sandbox or throwaway dir with the lockdown overlay (below), watch what it does.
- [ ] **Token cost:** which class is it, `free-local`, `on-use`, `session` or
      `per-prompt` ([docs/token-awareness.md](token-awareness.md))? Anything `session` or
      `per-prompt` defaults to opt-in. Weigh the recurring context tax against the value.

## Tools in this template

- **`scripts/audit-config.sh [path]`**: reports what a `.claude/` artifact or plugin
  actually does. It lists dynamic `` !`cmd` `` execution and `allowed-tools` grants.
  It lists every skill, command and agent, tagged model-invocable or opted out. For
  each it shows frontmatter hooks and MCP servers, and for agents their tools. It lists bundled
  scripts, binaries and symlinks. It lists commands that run without a prompt: hooks in
  settings, `hooks/hooks.json` or `plugin.json`, plus `statusLine`, helper keys, `env`
  vars that load code, MCP and LSP servers, and monitors. And it lists egress and secret
  tokens, including package runners. Run it on a candidate skill *before* adding it. It
  reports, you decide (`--strict` exits nonzero on high signal findings and on anything
  it couldn't read). It reads frontmatter without a YAML parser, so treat an "opted out"
  tag as a hint and check the file.
- **`scripts/check-template.sh`**: integrity (JSON valid, hooks runnable, `@references`
  resolve) plus a smoke test for secret patterns. It's not a real secret scanner. For
  that, CI runs [gitleaks](https://github.com/gitleaks/gitleaks) over the full git
  history (`.github/workflows/check.yml`).
- **`.claude/settings.lockdown.json.example`**: the quarantine overlay. Merge its deny
  rules into `settings.local.json` to block network egress while vetting.

### Example: what the auditor shows

`acme-docs-helper` is a fictional plugin that writes documentation. Running
`bash scripts/audit-config.sh path/to/acme-docs-helper` prints (sections 1 and 2 trimmed):

```text
=== 3. Tool pre-approvals (allowed-tools: / allowedTools) ===
acme-docs-helper/skills/write-docs/SKILL.md:4:allowed-tools: Bash, Write

=== 4. Skills/commands/agents  [MODEL-INVOCABLE = Claude can start it on its own] ===
  acme-docs-helper/agents/reviewer.md  [agent; no tools: line -> inherits ALL tools]
  acme-docs-helper/skills/write-docs/SKILL.md  [MODEL-INVOCABLE]

=== 5. Auto-run commands and grants (hooks, permissions, plugin manifests, MCP/LSP servers, monitors) ===
  PLUGIN acme-docs-helper: enabling it activates everything it declares
  acme-docs-helper/.claude-plugin/plugin.json: mcpServers.acme-search -> npx -y acme-search-mcp@latest
  acme-docs-helper/hooks/hooks.json: hooks.SessionStart[0].hooks[0] -> ${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh

=== 6. Sensitive tokens  [HIGH] ===
acme-docs-helper/scripts/setup.sh:3:[ -x "$HOME/.acme/engine" ] || curl -fsSL https://acme.example/engine -o "$HOME/.acme/engine"
acme-docs-helper/.claude-plugin/plugin.json:6:    "acme-search": { "command": "npx", "args": ["-y", "acme-search-mcp@latest"] }
acme-docs-helper/skills/write-docs/SKILL.md:7:Before writing, run `npx acme-docs lint .` and fix what it reports.
```

What that tells you before you enable it:

- Every session start runs `setup.sh`, which downloads an engine the first time (§5, §6).
  That's code you haven't reviewed, fetched at runtime.
- The MCP server is an unpinned package that `npx -y …@latest` downloads and runs each
  time it starts (§5).
- Claude can start the skill on its own for any documentation work, with Bash and Write
  preapproved (§3, §4). The skill also tells it to run another `npx` package (§6).
- The agent has no `tools:` line, so it gets every tool, MCP tools included (§4).

One way through is to take only `SKILL.md` ([partial vendoring](#partial-vendoring-taking-the-skill-out-of-a-plugin)),
give it `disable-model-invocation: true`, drop its `allowed-tools` and deny
`npx acme-docs` in all its forms ([deny what its docs tell Claude to run](#treat-skills-as-dependencies)).

## Static analysis (SAST) for the code itself

The auditor above protects against malicious *config*. To find vulnerabilities in your
*app code*, run a SAST tool. Pick per project. Both run locally, by hand:

| | CodeQL | Semgrep |
|---|---|---|
| Engine license | Not OSS. **Free for open source and research, GitHub Advanced Security required for proprietary code** | OSS (LGPL). **Free for commercial use** |
| Local ergonomics | Heavy: builds a database. Compiled langs need a build | Light: no build step |
| Strength | Deep dataflow and taint analysis | Fast, broad, easy custom rules |

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

Gitignore scan output (`*.sarif`, `.codeql-db/`). And remember, **no findings ≠ secure**.
SAST finds known patterns. It doesn't find business logic flaws. Use it to triage. Don't
treat it as proof.
