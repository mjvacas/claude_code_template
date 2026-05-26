# Security Policy

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue.

- Contact: `<fill in: security email or private channel>`
- Or use GitHub's private vulnerability reporting (Security tab → "Report a vulnerability").

Include steps to reproduce and the impact you observed. We'll acknowledge receipt and
keep you updated on the fix.

## Scope

This is a project template. The relevant attack surface is the **AI-config trust model** —
skills, slash commands, subagents, hooks, and MCP servers are code that runs on your
machine. The threat model, vetting checklist, and the deny-list backstop are documented in
[`docs/skill-security.md`](docs/skill-security.md). Before adopting anything from outside
your own repo, run `bash scripts/audit-config.sh <path>` and review it.

## Secrets

Never commit secrets. `.gitignore` and the `settings.json` deny-list block the common
cases, and `scripts/check-template.sh` (also run in CI) fails on tracked secret material.
Keep real secrets in environment variables or an untracked `.env`.
