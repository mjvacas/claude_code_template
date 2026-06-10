#!/usr/bin/env bash
# SessionStart hook — anchors the session in time and surfaces recent repo
# activity so every session opens with current state. stdout is injected into
# Claude's context. Outside a git repo only the clock line prints. Remove this
# hook or this script freely; see docs/claude-code-setup.md.
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

# Session-start clock anchor. The opt-in per-prompt clock.sh heartbeat (see
# docs/claude-code-setup.md) keeps time current; subtracting this line from
# its output gives elapsed session time.
echo "Session started: $(date '+%Y-%m-%d %H:%M %Z (%A)')"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

echo
echo "## Recent repo activity (SessionStart hook)"
echo
echo "### Last 5 commits"
git log --oneline -5 2>/dev/null || true
echo
echo "### Working tree status"
git status --short 2>/dev/null || true

# Nag if AI_CONTEXT.md has grown past the archive threshold. Silent below it.
# Threshold rationale: docs/adr/ADR-004-ai-context-archive-threshold-bump.md
# (supersedes ADR-002 — original 500-line research-anchored derivation)
if [ -f AI_CONTEXT.md ]; then
  lines=$(wc -l < AI_CONTEXT.md | tr -d ' ')
  if [ "$lines" -gt 750 ]; then
    echo
    echo "### AI_CONTEXT.md needs archiving (${lines} lines > 750)"
    echo "Move oldest session blocks into docs/summaries/$(date +%Y-%m).md before /handoff."
    echo "See docs/adr/ADR-004-ai-context-archive-threshold-bump.md for the why."
  fi
fi
exit 0
