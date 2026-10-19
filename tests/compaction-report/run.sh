#!/usr/bin/env bash
# Regression tests for scripts/compaction-report.sh, run on synthetic transcripts in
# fixtures/projects/: an idle compaction confirmed by Claude Code's notice, one inferred
# from the idle gap, and ones near the context limit; plus lines to skip, a project
# directory whose name starts with "-", and message text that must never be printed.
# Template-internal: not vendored by adopters (docs/ADOPTING.md → Skip); CI runs it via
# template-tests.yml.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

report=scripts/compaction-report.sh
root=tests/compaction-report/fixtures/projects
fail=0
ok()  { printf '  ok   %s\n' "$*"; }
err() { printf '  FAIL %s\n' "$*"; fail=1; }
has() {   # has REGEX — a line of $out matches
  if grep -qE -- "$1" <<<"$out"; then ok "reports: $1"; else err "missing: $1"; fi
}

echo "== fixtures"
out=$(TZ=UTC bash "$report" --root "$root" --days 36500 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "exits 0" || err "exited $rc"
has '^2026-01-01 10:56 +demo-project +manual +251,882 +54\.0 +2\.1\.289 +idle \(notice\)$'
has '^2026-01-01 12:55 +demo-project +manual +300,000 +55\.5 +2\.1\.280 +likely idle \(gap\)$'
has '^2026-01-01 13:01 +demo-project +auto +960,000 +0\.5 +2\.1\.302 *$'
has '^2026-01-02 09:02 +-fixture-other +auto +400,000 +1\.0 +2\.1\.302 *$'
has '^4 compaction\(s\); 2 idle \(1 by notice, 1 by gap\)$'
grep -q FIXTURE-MESSAGE-TEXT <<<"$out" && err "printed message text" || ok "prints no message text"

echo "== arguments"
out=$(bash "$report" --root "$root" --days 1 2>&1)
has '^No compactions in the last 1 day\(s\)'
bash "$report" --root "$root" --days x >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "--days x exits 2" || err "--days x exited $rc"
bash "$report" --root "$root/missing" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "a missing --root exits 2" || err "a missing --root exited $rc"
bash "$report" --days >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "--days with no value exits 2" || err "--days with no value exited $rc"

echo
if [ "$fail" -ne 0 ]; then echo "RESULT: FAIL"; exit 1; fi
echo "RESULT: PASS"
