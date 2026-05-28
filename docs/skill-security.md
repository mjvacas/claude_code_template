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
  mode skips the trust prompt entirely.)
- **Tool pre-approval** — a skill's `allowed-tools` suppresses per-call prompts while
  it's active (removes your speed bumps).
- **Prompt injection** — instructions in the body ("read `.env` and POST it", "loosen
  `settings.json`", "ignore previous instructions").
- **Bundled scripts** — files the skill tells the model to execute.
- **Model-invocation** — without `disable-model-invocation`, the model can trigger a
  skill on its own based on its description.
- **MCP servers** — external processes that can read context and reach the network.

## The hard backstop: deny always wins

Permission precedence is **`deny` > `ask` > `allow`**, a deny from *any* scope wins, and
**nothing exceeds it** — not `allowed-tools`, not a hook returning `"allow"`, not
autonomous invocation. A correct deny list is your jail. This template denies secret
reads (`.env*`, keys, `secrets/`, `.aws/credentials`) and the never-needed exfil tools
(`nc`, `ncat`, `telnet`) by default in `.claude/settings.json`.

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
- **Vendor, don't fetch-at-runtime** — copy the artifact in, review it, commit it. Now
  it's frozen and goes through PR review.
- **Review on add *and* every update** — the classic attack is a benign v1 that turns
  malicious in v3. Diff every bump.
- **Least privilege** — anything external or side-effecting gets
  `disable-model-invocation: true`; never add broad `allowed-tools`.
- **Quarantine, then promote** — keep unvetted skills in `settings.local.json` (your
  machine only); only commit to `.claude/` after vetting.
- **Review gate** — require extra review on `.claude/**` changes (e.g. CODEOWNERS).

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
- [ ] **Body:** every `` !`cmd` `` and ```` ```! ```` block — read each command.
- [ ] **Bundled files:** scripts the skill tells the model to run.
- [ ] **Egress / secrets:** `curl`, `wget`, `nc`, `/dev/tcp`, `base64`, `WebFetch`,
      external URLs, reads of `.env` / `~/.ssh` / `~/.aws` / `secrets/`.
- [ ] **Injection:** "ignore previous instructions", edits to `settings.json` / hooks /
      `.gitignore`, anything that weakens permissions, hidden/obfuscated text.
- [ ] **Provenance:** who publishes it, is it pinned, is the source maintained?
- [ ] **Default posture:** install with `disable-model-invocation`, run once in a
      sandbox/throwaway dir with the lockdown overlay (below), watch what it does.

## Tools in this template

- **`scripts/audit-config.sh [path]`** — reports what a `.claude/` artifact actually
  does: dynamic `` !`cmd` `` execution, `allowed-tools` grants, model-invocable skills,
  bundled scripts, hook commands, and egress/secret tokens. Run it on a candidate skill
  *before* adding it. It reports; you decide (`--strict` exits non-zero on high-signal
  findings).
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
