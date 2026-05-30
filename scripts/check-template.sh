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
#   5. Safety guard + scaffolding: PreToolUse dangerous-command hook is wired,
#      and the directories the commands/CLAUDE.md reference exist
#   6. Posture invariants: the specific deny/.gitignore/regex lines that have
#      silently regressed in the past (e.g. via an unrebased branch) stay present
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
ok()  { printf '  ok   %s\n' "$*"; }
err() { printf '  FAIL %s\n' "$*"; fail=1; }

# Files matching given globs: tracked files in a git repo (skips node_modules/.venv
# etc. for free), else a pruned find fallback for a non-git checkout.
list_files() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -- "$@" ':!old/'
  else
    local args=() pat
    for pat in "$@"; do args+=(-o -name "$pat"); done
    find . \( -path './.git' -o -path '*/node_modules' -o -path '*/.venv' \
      -o -path '*/venv' -o -path '*/dist' -o -path '*/build' \
      -o -path './old' -o -path './.claude/snapshots' \) -prune -o \
      \( "${args[@]:1}" \) -type f -print
  fi
}

echo "== 1. JSON validity =="
while IFS= read -r f; do
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
    ok "$f"
  else
    err "invalid JSON: $f"
  fi
done < <(list_files '*.json' '*.json.example' | sort)

echo "== 2. Shell scripts (hooks + statusline) =="
scripts=$(ls .claude/hooks/*.sh .claude/statusline.sh 2>/dev/null || true)
if [ -n "$scripts" ]; then
  for h in $scripts; do
    [ -x "$h" ] || err "not executable (chmod +x): $h"
    if bash -n "$h" 2>/dev/null; then ok "$h"; else err "bash syntax error: $h"; fi
  done
else
  ok "no shell scripts"
fi

echo "== 3. @references resolve =="
if ! python3 - <(list_files '*.md') <<'PY'
import os, re, sys
ref_re = re.compile(r'(?:^|[\s(])@([A-Za-z0-9._\-/~]+)')
with open(sys.argv[1], encoding='utf-8') as lf:
    files = [ln.strip() for ln in lf if ln.strip()]
broken, checked = [], 0
for src in files:
    try:
        fh = open(src, encoding='utf-8', errors='ignore')
    except OSError:
        continue
    with fh:
        for line in fh:
            for raw in ref_re.findall(line):
                ref = raw.rstrip('.')
                if '/' not in ref and '.' not in ref:   # not a path-like token
                    continue
                if ref.startswith('~'):                  # home import; can't verify
                    continue
                if not os.path.splitext(os.path.basename(ref))[1]:  # package-style, e.g. @anthropic-ai/sdk
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
    | grep -E '(^|/)\.env($|\.)|\.pem$|\.p12$|\.pfx$|\.keystore$|\.key$|_key$|_secret$|(^|/)id_(rsa|ed25519)$|(^|/)\.aws/credentials$' \
    | grep -vE '\.example$' || true)
  if [ -n "$secret_files" ]; then
    err "secret-like files tracked by git:"; printf '       %s\n' $secret_files
  else
    ok "no secret-like files tracked"
  fi

  secret_re='-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|ghp_[0-9A-Za-z]{36}|xox[baprs]-[0-9A-Za-z-]{10,}|AIza[0-9A-Za-z_\-]{35}'
  # -e marks the pattern explicitly; without it git grep reads the leading
  # "-----BEGIN…" as an option and aborts (the scan would silently never run).
  # cut redacts to file:line so a matched secret never lands in logs/CI output.
  hits=$(git grep -nIE -e "$secret_re" -- ':!old/' ':!*.example' ':!scripts/check-template.sh' 2>/dev/null | cut -d: -f1,2 || true)
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

# Local secret-bearing files (when present at the repo root) should be owner-only
# (mode 600). Mirrors the .gitignore / settings.json deny patterns at the
# filesystem-ACL layer. Silent when no matching files exist — template repos and
# most CI checkouts have none. Root-level only; adopters with deeper layouts
# (e.g. `secrets/`) can extend the patterns list.
shopt -s nullglob
for pattern in '.env' '.env.*' '.mcp.json' '.claude/settings.local.json' \
               '*.pem' '*.key' '*.p12' '*.pfx' '*.keystore' \
               '*_key' '*_secret' 'id_rsa' 'id_ed25519'; do
  for path in $pattern; do
    [ -f "$path" ] || continue
    case "$path" in *.example) continue ;; esac
    mode=$(stat -f '%Lp' "$path" 2>/dev/null || stat -c '%a' "$path" 2>/dev/null || echo "?")
    if [ "$mode" = "600" ]; then
      ok "$path mode is 600"
    else
      err "$path mode is $mode (expected 600 — chmod 600 $path)"
    fi
  done
done
shopt -u nullglob

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

echo "== 6. Posture invariants (silent-regression defense) =="
# Assert the specific posture lines that have been silently regressable in the
# past (e.g. a docs-titled branch forked off pre-hardening main, never rebased,
# whose diff against main looked like deletions of deny-list / redaction lines).
# These checks ensure those exact protections stay present.
if ! python3 - <<'PY'
import json, re, sys
posture_fail = 0
def ok(m): print(f"  ok   {m}")
def err(m):
    global posture_fail
    posture_fail = 1
    print(f"  FAIL {m}")

deny = set(json.load(open('.claude/settings.json'))['permissions']['deny'])
for pat in ('**/*_key', '**/*_secret', '**/*.pfx', '**/*.keystore'):
    glob = f'Read({pat})'
    (ok if glob in deny else err)(f"settings.json deny includes {glob}")

gi = open('.gitignore').read()
for pat in ('*_key', '*_secret'):
    if re.search(rf'^{re.escape(pat)}\s*$', gi, re.M):
        ok(f".gitignore contains {pat}")
    else:
        err(f".gitignore missing {pat}")

src = open('scripts/check-template.sh').read()
re_markers = ['_key$', '_secret$', r'\.keystore$']
missing = [m for m in re_markers if m not in src]
if missing:
    err(f"check-template.sh secret_files regex missing: {', '.join(missing)}")
else:
    ok("check-template.sh secret_files regex covers _key/_secret/.keystore")

for marker, name in [
    ('git grep -nIE -e "$secret_re"', 'check-template.sh secret-content scan uses -e (otherwise silently never runs)'),
    ('cut -d: -f1,2', 'check-template.sh secret-content scan redacts matches to file:line'),
]:
    (ok if marker in src else err)(name)

sys.exit(posture_fail)
PY
then fail=1; fi

echo
if [ "$fail" -ne 0 ]; then echo "RESULT: FAIL"; exit 1; fi
echo "RESULT: PASS"
