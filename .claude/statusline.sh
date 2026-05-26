#!/usr/bin/env bash
# statusLine command — renders the bottom-of-screen status. Claude Code pipes a JSON
# event on stdin; stdout (first line) becomes the status line. Kept deliberately small
# and dependency-free (bash, python3, git). Shows: model · dir · git-branch, plus a
# context warning when the session exceeds the large-context threshold.
#
# Schema note: field names in the status event have evolved across Claude Code versions
# (e.g. model.display_name, workspace.current_dir, exceeds_200k_tokens). This script
# reads them defensively and omits anything missing — adjust if your version differs.
set -euo pipefail

input=$(cat 2>/dev/null || echo '{}')

read -r model dir warn <<EOF
$(printf '%s' "$input" | python3 -c '
import json, sys, os
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
model = (d.get("model") or {}).get("display_name") or (d.get("model") or {}).get("id") or "?"
cwd = (d.get("workspace") or {}).get("current_dir") or d.get("cwd") or os.getcwd()
warn = "!ctx" if d.get("exceeds_200k_tokens") else "-"
print(model.replace(" ", "_"), os.path.basename(cwd) or "/", warn)
' 2>/dev/null || echo "? . -")
EOF

branch=$(git branch --show-current 2>/dev/null || echo "")

line="${model//_/ } · ${dir}"
[ -n "$branch" ] && line="$line · ⎇ $branch"
[ "$warn" = "!ctx" ] && line="$line · ⚠ >200k ctx"
printf '%s\n' "$line"
