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

# Nag if AI_CONTEXT.md has grown past the archive threshold. Silent below it.
# Threshold rationale + sources: docs/adr/ADR-002-ai-context-archive-threshold.md
if [ -f AI_CONTEXT.md ]; then
  lines=$(wc -l < AI_CONTEXT.md | tr -d ' ')
  if [ "$lines" -gt 500 ]; then
    echo
    echo "### AI_CONTEXT.md needs archiving (${lines} lines > 500)"
    echo "Move oldest session blocks into docs/summaries/$(date +%Y-%m).md before /handoff."
    echo "See docs/adr/ADR-002-ai-context-archive-threshold.md for the why."
  fi
fi
exit 0
