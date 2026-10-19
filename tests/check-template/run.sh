#!/usr/bin/env bash
# Mutation tests for scripts/check-template.sh: a copy of the repo must pass, and each
# copy with one protection broken must fail with the matching message. Proves the
# checks can fail at all (two of them once couldn't). Template-internal: not vendored by
# adopters (docs/ADOPTING.md → Skip); CI runs it via template-tests.yml.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

fail=0
ok()  { printf '  ok   %s\n' "$*"; }
err() { printf '  FAIL %s\n' "$*"; fail=1; }

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT

# The repo as an adopter would have it: tracked plus untracked-but-unignored files.
mkdir "$tmp/pristine"
git ls-files -co --exclude-standard -z | tar --null -T - -cf - | (cd "$tmp/pristine" && tar -xf -)
(cd "$tmp/pristine" && git init -q && git add -A) || exit 1

echo "== pristine copy"
if out=$(cd "$tmp/pristine" && bash scripts/check-template.sh 2>&1); then
  ok "passes"
else
  err "fails:"; grep FAIL <<<"$out"
fi

# mutant NAME EXPECT CMD... — copy the pristine repo, run CMD inside it, and require the
# check to fail with a line containing EXPECT.
mutant() {
  local name=$1 expect=$2 rc; shift 2
  rm -rf "$tmp/m"; cp -R "$tmp/pristine" "$tmp/m"
  (cd "$tmp/m" && "$@") || { err "$name: mutation didn't apply"; return; }
  out=$(cd "$tmp/m" && bash scripts/check-template.sh 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && grep -qF -- "$expect" <<<"$out"; then ok "$name fails the check"
  else err "$name passes the check (rc=$rc)"; fi
}
unwire_guard() {
  python3 -I -c 'import json; p = ".claude/settings.json"; d = json.load(open(p)); del d["hooks"]["PreToolUse"]; json.dump(d, open(p, "w"), indent=2)'
}
drop_ssh_deny() {
  python3 -I -c 'import json; p = ".claude/settings.json"; d = json.load(open(p)); d["permissions"]["deny"].remove("Read(~/.ssh/**)"); json.dump(d, open(p, "w"), indent=2)'
}
readable_snapshot() {
  mkdir -p .claude/snapshots && printf 'x\n' > .claude/snapshots/2026-01-01T00-00-00-fixture.md &&
    chmod 644 .claude/snapshots/2026-01-01T00-00-00-fixture.md
}
drop_dash_e() {   # only the scan itself, not the marker §6 looks for
  sed -i.bak '/^  hits=/s/git grep -nIE -e /git grep -nIE /' scripts/check-template.sh &&
    grep -q '^  hits=$(git grep -nIE "' scripts/check-template.sh
}

echo "== mutations"
mutant "deleted guard script" "block-dangerous.sh is missing" rm .claude/hooks/block-dangerous.sh
mutant "unwired guard" "does not wire .claude/hooks/block-dangerous.sh" unwire_guard
mutant "non-executable status line" "statusline.sh is not executable" chmod -x .claude/statusline.sh
mutant "secret scan without -e" "secret-content scan uses -e" drop_dash_e
mutant "no ~/.ssh deny" "missing home credential stores: Read(~/.ssh/**)" drop_ssh_deny
mutant "world-readable snapshot" "2026-01-01T00-00-00-fixture.md mode is 644" readable_snapshot

echo
if [ "$fail" -ne 0 ]; then echo "RESULT: FAIL"; exit 1; fi
echo "RESULT: PASS"
