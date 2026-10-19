#!/usr/bin/env bash
# Regression tests for .claude/hooks/block-dangerous.sh. Each case in cases.txt is fed to
# the hook as a PreToolUse event (never executed) and must be blocked (exit 2, a deny
# JSON on stdout, "BLOCKED:" on stderr) or allowed (exit 0, nothing on stdout).
# Template-internal: not vendored by adopters (docs/ADOPTING.md → Skip); CI runs it via
# template-tests.yml.
#
# Every case runs three ways, because the hook must not fail open when python3 is gone:
# with python3, with no python3 on PATH, and with a python3 that just fails (the stub a
# Mac without the Xcode tools has). Each also runs under /bin/bash when that differs
# from the bash on PATH, so macOS's bash 3.2 is covered.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

hook=.claude/hooks/block-dangerous.sh
cases=tests/block-dangerous/cases.txt
fail=0
ok()  { printf '  ok   %s\n' "$*"; }
err() { printf '  FAIL %s\n' "$*"; fail=1; }

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/nopy" "$tmp/badpy"
for t in cat grep sed; do
  ln -s "$(command -v "$t")" "$tmp/nopy/$t"
  ln -s "$(command -v "$t")" "$tmp/badpy/$t"
done
printf '#!/bin/sh\nexit 1\n' > "$tmp/badpy/python3"
chmod +x "$tmp/badpy/python3"

shells=$(command -v bash)
[ -x /bin/bash ] && ! [ /bin/bash -ef "$shells" ] && shells="$shells /bin/bash"

# event TOOL CMD — print a PreToolUse event (built with python3; only the hook goes without).
event() {
  python3 -I -c 'import json, sys; print(json.dumps({"tool_name": sys.argv[1], "tool_input": {"command": sys.argv[2]}}))' "$1" "$2"
}
# run_hook MODE SHELL < EVENT — run the hook; sets rc, and leaves stdout/stderr in files.
run_hook() {
  case $1 in
    python) "$2" "$hook" > "$tmp/out" 2> "$tmp/errout" ;;
    *) PATH="$tmp/$1" "$2" "$hook" > "$tmp/out" 2> "$tmp/errout" ;;
  esac
  rc=$?
}
# verdict WANT EVENT — run every mode and shell; print nothing when all agree with WANT,
# else "mode shell rc=N" for each one that didn't.
verdict() {
  local bad="" m s
  for m in python nopy badpy; do
    for s in $shells; do
      run_hook "$m" "$s" <<<"$2"
      if grep -q Traceback "$tmp/errout"; then bad="$bad [$m $s: traceback]"; continue; fi
      case $1 in
        BLOCK) [ "$rc" -eq 2 ] && grep -q '"permissionDecision":"deny"' "$tmp/out" &&
                 grep -q '^BLOCKED:' "$tmp/errout" || bad="$bad [$m $s: rc=$rc]" ;;
        ALLOW) [ "$rc" -eq 0 ] && [ ! -s "$tmp/out" ] || bad="$bad [$m $s: rc=$rc]" ;;
      esac
    done
  done
  printf '%s' "$bad"
}

echo "== $cases"
first_block=""
while IFS= read -r line; do
  case $line in ''|'#'*) continue ;; esac
  want=${line%% *}; c=${line#* }
  c=${c//<NL>/$'\n'}
  [ "$want" = BLOCK ] && [ -z "$first_block" ] && first_block=$c
  bad=$(verdict "$want" "$(event Bash "$c")")
  if [ -z "$bad" ]; then ok "$want $line"; else err "$want $line$bad"; fi
done < "$cases"

echo "== generated cases"
# A dangerous command followed by >64KB of text: `grep -q` + pipefail used to let it through.
pad=$(printf '%100000s' '' | tr ' ' 'a')
bad=$(verdict BLOCK "$(event Bash "$first_block"$'\n'"$pad")")
[ -z "$bad" ] && ok "BLOCK first case + 100KB of text" || err "BLOCK first case + 100KB of text$bad"
# The deny JSON must parse, with and without python3 in the hook.
for m in python nopy badpy; do
  run_hook "$m" "${shells%% *}" <<<"$(event Bash "$first_block")"
  if python3 -I -c 'import json, sys; d = json.load(open(sys.argv[1])); assert d["hookSpecificOutput"]["permissionDecision"] == "deny"' "$tmp/out" 2>/dev/null; then
    ok "deny JSON parses ($m)"; else err "deny JSON doesn't parse ($m)"; fi
done
# Other tools and malformed input pass untouched.
bad=$(verdict ALLOW "$(event Write "$first_block")")
[ -z "$bad" ] && ok "ALLOW the same text from the Write tool" || err "ALLOW the same text from the Write tool$bad"
for raw in '{}' 'not json' ''; do
  bad=$(verdict ALLOW "$raw")
  [ -z "$bad" ] && ok "ALLOW input: '${raw}'" || err "ALLOW input: '${raw}'$bad"
done

echo
if [ "$fail" -ne 0 ]; then echo "RESULT: FAIL"; exit 1; fi
echo "RESULT: PASS"
