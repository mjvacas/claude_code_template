#!/usr/bin/env bash
# Template self-check — integrity + secrets hygiene.
# Run locally (`bash scripts/check-template.sh`) or in CI. Zero third-party deps
# (bash, git, python3, grep). Exits non-zero on any failure.
#
# Checks:
#   1. Every *.json / *.json.example parses
#   2. Hook scripts are executable and pass `bash -n`
#   3. Every @reference in *.md resolves to a real file
#   4. Secrets hygiene: no secret files tracked, no obvious secret material in
#      tracked content, and the protections (.gitignore + settings deny) are present
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
ok()  { printf '  ok   %s\n' "$*"; }
err() { printf '  FAIL %s\n' "$*"; fail=1; }

echo "== 1. JSON validity =="
while IFS= read -r f; do
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
    ok "$f"
  else
    err "invalid JSON: $f"
  fi
done < <(find . -not -path './.git/*' \( -name '*.json' -o -name '*.json.example' \) | sort)

echo "== 2. Hook scripts =="
if compgen -G ".claude/hooks/*.sh" >/dev/null; then
  for h in .claude/hooks/*.sh; do
    [ -x "$h" ] || err "not executable (chmod +x): $h"
    if bash -n "$h" 2>/dev/null; then ok "$h"; else err "bash syntax error: $h"; fi
  done
else
  ok "no hook scripts"
fi

echo "== 3. @references resolve =="
if ! python3 - <<'PY'
import os, re, sys
ref_re = re.compile(r'(?:^|[\s(])@([A-Za-z0-9._\-/~]+)')
broken, checked = [], 0
for dp, _, fs in os.walk('.'):
    if dp.startswith('./.git') or dp.startswith('./old') or dp.startswith('./.claude/snapshots'):
        continue
    for fn in fs:
        if not fn.endswith('.md'):
            continue
        src = os.path.join(dp, fn)
        with open(src, encoding='utf-8', errors='ignore') as fh:
            for line in fh:
                for raw in ref_re.findall(line):
                    ref = raw.rstrip('.')
                    if '/' not in ref and '.' not in ref:   # not a path-like token
                        continue
                    if ref.startswith('~'):                  # home import; can't verify
                        continue
                    checked += 1
                    cands = [ref, os.path.join(os.path.dirname(src), ref)]
                    if not any(os.path.exists(c) for c in cands):
                        broken.append((src, ref))
for src, ref in broken:
    print(f"  FAIL @{ref}  (referenced in {src})")
print(f"  checked {checked} reference(s); {len(broken)} broken")
sys.exit(1 if broken else 0)
PY
then fail=1; fi

echo "== 4. Secrets hygiene =="
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  secret_files=$(git ls-files \
    | grep -E '(^|/)\.env($|\.)|\.pem$|\.p12$|\.pfx$|\.key$|(^|/)id_(rsa|ed25519)$|(^|/)\.aws/credentials$' \
    | grep -vE '\.example$' || true)
  if [ -n "$secret_files" ]; then
    err "secret-like files tracked by git:"; printf '       %s\n' $secret_files
  else
    ok "no secret-like files tracked"
  fi

  secret_re='-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|ghp_[0-9A-Za-z]{36}|xox[baprs]-[0-9A-Za-z-]{10,}|AIza[0-9A-Za-z_\-]{35}'
  hits=$(git grep -nIE "$secret_re" -- ':!old/' ':!*.example' ':!scripts/check-template.sh' 2>/dev/null || true)
  if [ -n "$hits" ]; then
    err "possible secret material in tracked files:"; printf '       %s\n' "$hits"
  else
    ok "no obvious secret patterns in tracked content"
  fi
else
  ok "not a git repo — skipping tracked-file secret scan"
fi

# Protections must stay in place
grep -qE '(^|/)\.env' .gitignore 2>/dev/null \
  && ok ".gitignore ignores .env files" \
  || err ".gitignore does not ignore .env files"

if python3 -c "import json; d=json.load(open('.claude/settings.json')); deny=d.get('permissions',{}).get('deny',[]); raise SystemExit(0 if any('.env' in r for r in deny) else 1)" 2>/dev/null; then
  ok "settings.json deny list covers .env reads"
else
  err "settings.json deny list does not cover .env reads"
fi

echo "== 5. Safety guard + scaffolding =="
# The PreToolUse guard must stay wired (deleting the script or the wiring is caught here).
if python3 -c "import json; d=json.load(open('.claude/settings.json')); pt=d.get('hooks',{}).get('PreToolUse',[]); raise SystemExit(0 if any('block-dangerous' in h.get('command','') for g in pt for h in g.get('hooks',[])) else 1)" 2>/dev/null; then
  ok "settings.json wires the PreToolUse dangerous-command guard"
else
  err "settings.json does not wire .claude/hooks/block-dangerous.sh as a PreToolUse hook"
fi
# Directories referenced by CLAUDE.md / AI_CONTEXT.md / commands must exist.
for d in docs/adr docs/summaries; do
  if [ -d "$d" ]; then ok "$d/ exists"; else err "missing directory: $d"; fi
done

echo
if [ "$fail" -ne 0 ]; then echo "RESULT: FAIL"; exit 1; fi
echo "RESULT: PASS"
