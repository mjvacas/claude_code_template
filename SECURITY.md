# Security Policy

## Reporting a vulnerability

Please report security issues **privately**. Do not open a public issue.

- Use GitHub's private vulnerability reporting (Security tab → "Report a vulnerability").

Include steps to reproduce and the impact you observed. We'll acknowledge receipt and
keep you updated on the fix.

## Scope

> Customize this section for your project (the services, endpoints, and data it handles).

Because this project is built from the Claude Code template, the **AI config trust model**
is part of the attack surface. Skills, slash commands, subagents, hooks, and MCP servers
are code that runs on your machine. [`docs/skill-security.md`](docs/skill-security.md)
documents the threat model, vetting checklist, and the deny list backstop. Before
adopting anything from outside your own repo, run `bash scripts/audit-config.sh <path>`
and review it.

## Secrets

Never commit secrets. `.gitignore` and the `settings.json` deny list block the common
cases. `scripts/check-template.sh` (also run in CI) fails on tracked secret material.
Keep real secrets in environment variables or an untracked `.env`.

After creating any local file that holds secrets, run `chmod 600 <path>` to restrict it
to your user. That covers `.env`, `.env.*`, `.mcp.json`, `.claude/settings.local.json`,
private keys (`*.pem`, `*.key`, `id_rsa`, etc.), and extensionless `*_key` and
`*_secret` files. This defends against readers on a shared machine, lax backup tools,
and SDKs (`gcloud`, `ssh`) that refuse to load files with permissive modes. The
self-check asserts this for any of these patterns it finds at the repo root.

The `*.key` pattern targets **private** keys (public keys are conventionally `*.pub`
or `*.crt`). A `.key` file at the repo root that isn't secret will FAIL the mode
check by design. The check fails closed and treats any `.key` as sensitive until you
rename it or move it out of the patterns' reach.
