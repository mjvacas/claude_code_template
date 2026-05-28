#!/usr/bin/env bash
# audit-config.sh — report what Claude Code config in a path ACTUALLY does, so you
# can vet a skill / command / agent / hook before trusting it.
#
# This is a REVIEW AID for a human, not a pass/fail gate: legitimate config trips
# many of these checks (e.g. our own hooks use git). Read the report, then decide.
# Pairs with docs/skill-security.md (the vetting checklist).
#
# Usage:
#   scripts/audit-config.sh [PATH]            # default: .claude
#   scripts/audit-config.sh path/to/SKILL.md  # a single candidate skill
#   scripts/audit-config.sh --strict [PATH]   # exit 1 if any HIGH-signal finding
set -uo pipefail

strict=0
[ "${1:-}" = "--strict" ] && { strict=1; shift; }
cd "$(dirname "$0")/.." || exit 1
target="${1:-.claude}"
[ -e "$target" ] || { echo "audit-config: no such path: $target" >&2; exit 2; }

high=0
hdr() { printf '\n=== %s ===\n' "$*"; }

md_files=$(find "$target" -type f -name '*.md' 2>/dev/null)
script_files=$(find "$target" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.js' -o -name '*.rb' \) 2>/dev/null)
json_files=$(find "$target" -type f \( -name 'settings*.json' -o -name 'settings*.json.example' \) 2>/dev/null)

hdr "1. Dynamic shell execution  [HIGH: runs at load time, before the model sees output]"
if grep -rnE '!`[^`]+`|^```!' $md_files /dev/null 2>/dev/null; then high=1; else echo "  none"; fi

hdr "2. Tool pre-approvals  (allowed-tools: suppresses per-call prompts while active)"
grep -rniE '^allowed-tools:' $md_files /dev/null 2>/dev/null || echo "  none"

hdr "3. Model-invocable skills/commands  (can self-trigger; no disable-model-invocation)"
found3=0
for f in $md_files; do
  case "$f" in
    */skills/*|*/commands/*)
      grep -qiE '^disable-model-invocation:[[:space:]]*true' "$f" || { echo "  $f"; found3=1; } ;;
  esac
done
[ "$found3" -eq 0 ] && echo "  none"

hdr "4. Bundled scripts / executables under the config path"
if [ -n "$script_files" ]; then printf '  %s\n' $script_files; else echo "  none"; fi

hdr "5. Hook commands configured in settings"
if [ -n "$json_files" ]; then
  for s in $json_files; do
    python3 - "$s" <<'PY' || true
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception as e:
    print(f"  ({p}: not valid JSON: {e})"); sys.exit(0)
hooks = d.get("hooks", {})
any_ = False
for event, groups in hooks.items():
    for g in groups or []:
        for h in g.get("hooks", []) or []:
            cmd = h.get("command") or h.get("url") or h.get("type")
            print(f"  {p}: {event} -> {cmd}"); any_ = True
if not any_:
    print(f"  ({p}: no hooks)")
PY
  done
else
  echo "  (no settings files in path)"
fi

hdr "6. Sensitive tokens  [HIGH: network egress, secret access, code-gen]"
danger='curl|wget|netcat|ncat|telnet|/dev/tcp|base64|https?://|/\.ssh|/\.aws|id_rsa|id_ed25519|credentials|/\.env|secrets/'
if grep -rniE "$danger" $md_files $script_files /dev/null 2>/dev/null; then high=1; else echo "  none"; fi

echo
echo "Reviewed: $(printf '%s\n' $md_files $script_files $json_files | grep -c . ) file(s) under '$target'."
echo "Reminder: this reports; YOU decide. See docs/skill-security.md."
if [ "$strict" -eq 1 ] && [ "$high" -eq 1 ]; then
  echo "STRICT: high-signal findings present -> exit 1"; exit 1
fi
exit 0
