# Security Policy

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue.

- Use GitHub's private vulnerability reporting (Security tab → "Report a vulnerability").

Include steps to reproduce and the impact you observed. We'll acknowledge receipt and
keep you updated on the fix.

## Scope

> Customize this section for your project — the services, endpoints, and data it handles.

Because this project is built from the Claude Code template, the **AI-config trust model**
is part of the attack surface — skills, slash commands, subagents, hooks, and MCP servers
are code that runs on your machine. The threat model, vetting checklist, and the deny-list
backstop are documented in [`docs/skill-security.md`](docs/skill-security.md). Before
adopting anything from outside your own repo, run `bash scripts/audit-config.sh <path>`
and review it.

## Secrets

Never commit secrets. `.gitignore` and the `settings.json` deny-list block the common
cases, and `scripts/check-template.sh` (also run in CI) fails on tracked secret material.
Keep real secrets in environment variables or an untracked `.env`.

After creating any local secret-bearing file — `.env` / `.env.*`, `.mcp.json`,
`.claude/settings.local.json`, private keys (`*.pem`, `*.key`, `id_rsa`, etc.),
or extensionless `*_key` / `*_secret` files — run `chmod 600 <path>` to restrict it
to your user. Defends against shared-machine readers, lax backup tools, and SDKs
(`gcloud`, `ssh`) that refuse to load files with permissive modes. The self-check
asserts this for any of these patterns it finds at the repo root.

The `*.key` pattern targets **private** keys (public keys are conventionally `*.pub`
or `*.crt`). A non-secret file with a `.key` suffix at the repo root will FAIL the
mode check by design — fail-closed treats any `.key` as sensitive until you rename it
or move it out of the patterns' reach.
