#!/usr/bin/env bash
# audit-config.sh — report what Claude Code config in a path ACTUALLY does, so you
# can vet a skill / command / agent / hook before trusting it.
#
# This is a REVIEW AID for a human, not a pass/fail gate: legitimate config trips
# many of these checks (our own commands use `!`git ...`` and our hooks mention curl).
# Read the report, then decide. Pairs with docs/skill-security.md (the checklist).
#
# Handles arbitrary filenames safely (spaces/newlines via -print0) and scans EVERY
# file regardless of extension, so a payload can't hide behind an odd name (`evil cmd.md`)
# or an unusual/absent extension (`setup.ts`, an extensionless binary).
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

# Binary = has a NUL byte or >30% non-printable bytes in the first 8KB. Catches compiled
# binaries (NUL-heavy) and high-entropy blobs; tolerant of normal UTF-8 text/source.
is_binary() {
  python3 - "$1" <<'PY' 2>/dev/null
import sys
try:
    d = open(sys.argv[1], "rb").read(8192)
except Exception:
    sys.exit(1)
if not d:
    sys.exit(1)
nonprint = sum(b == 0 or b < 9 or 13 < b < 32 or b > 126 for b in d)
sys.exit(0 if (b"\x00" in d or nonprint > len(d) * 0.30) else 1)
PY
}

# --- 1. Inventory: every file with perms, flagging executables and (unreviewable) binaries.
hdr "1. Files  [exec = gets run; BINARY = can't be reviewed by eye -> HIGH]"
n_files=0
while IFS= read -r -d '' f; do
  n_files=$((n_files + 1))
  mark="-"
  [ -x "$f" ] && mark="exec"
  if is_binary "$f"; then
    mark="BINARY"; high=1                 # non-text: unreviewable -> HIGH
  fi
  printf '  %-7s %s\n' "[$mark]" "$(ls -ldh -- "$f" 2>/dev/null)"
done < <(find "$target" -type f -print0 2>/dev/null)
[ "$n_files" -eq 0 ] && echo "  (no files)"

# --- 2. Dynamic shell execution: runs at LOAD time, before the model sees output.
hdr "2. Dynamic shell execution  [HIGH]"
if grep -rnIE '!`[^`]+`|^```!' -- "$target" 2>/dev/null; then high=1; else echo "  none"; fi

# --- 3. Tool pre-approvals (allowed-tools: suppresses per-call prompts while active).
hdr "3. Tool pre-approvals (allowed-tools:)"
grep -rniE '^allowed-tools:' -- "$target" 2>/dev/null || echo "  none"

# --- 4. Model-invocable skills/commands (can self-trigger; no disable-model-invocation).
hdr "4. Model-invocable skills/commands"
found=0
while IFS= read -r -d '' f; do
  case "$f" in
    */skills/*|*/commands/*)
      grep -qiE '^disable-model-invocation:[[:space:]]*true' -- "$f" 2>/dev/null \
        || { echo "  $f"; found=1; } ;;
  esac
done < <(find "$target" -type f -name '*.md' -print0 2>/dev/null)
[ "$found" -eq 0 ] && echo "  none"

# --- 5. Hook commands configured in settings.
hdr "5. Hook commands configured in settings"
settings=()
while IFS= read -r -d '' s; do settings+=("$s"); done \
  < <(find "$target" -type f \( -name 'settings*.json' -o -name 'settings*.json.example' \) -print0 2>/dev/null)
if [ "${#settings[@]}" -gt 0 ]; then
  for s in "${settings[@]}"; do
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

# --- 6. Sensitive tokens: network egress, secret access, code-gen. Scans ALL files.
hdr "6. Sensitive tokens  [HIGH]"
danger='curl|wget|netcat|ncat|telnet|/dev/tcp|base64|https?://|/\.ssh|/\.aws|id_rsa|id_ed25519|credentials|/\.env|secrets/'
if grep -rnIE "$danger" -- "$target" 2>/dev/null; then high=1; else echo "  none"; fi

echo
echo "Reviewed $n_files file(s) under '$target'."
echo "Reminder: this reports; YOU decide. See docs/skill-security.md."
if [ "$strict" -eq 1 ] && [ "$high" -eq 1 ]; then
  echo "STRICT: high-signal findings present -> exit 1"; exit 1
fi
exit 0
