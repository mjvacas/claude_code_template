#!/usr/bin/env bash
# UserPromptSubmit hook (OPT-IN — not wired by default) — injects the current
# wall-clock time into context on every prompt. Sessions have no inherent sense
# of time: the date injected at session start goes stale (midnight rollover,
# compaction), and the model can't otherwise notice elapsed time. Elapsed time
# is derivable by subtracting the "Session started" line that session-context.sh
# prints at SessionStart.
# Cost: a few tokens per prompt — which is why it ships unwired. To enable, add
# the UserPromptSubmit entry shown in docs/claude-code-setup.md to settings.json
# (or your settings.local.json for a personal-only clock).
set -euo pipefail
date '+[clock] %Y-%m-%d %H:%M %Z (%A)'
exit 0
