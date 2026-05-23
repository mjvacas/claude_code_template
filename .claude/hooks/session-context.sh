#!/usr/bin/env bash
# SessionStart hook — surfaces recent repo activity so every session opens with
# current state. stdout is injected into Claude's context. Safe no-op outside a
# git repo. Remove this hook or this script freely; see docs/claude-code-setup.md.
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

echo "## Recent repo activity (SessionStart hook)"
echo
echo "### Last 5 commits"
git log --oneline -5 2>/dev/null || true
echo
echo "### Working tree status"
git status --short 2>/dev/null || true
exit 0
