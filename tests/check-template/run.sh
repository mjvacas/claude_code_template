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
# check to fail with a line containing EXPECT (and without crashing).
mutant() {
  local name=$1 expect=$2 rc; shift 2
  rm -rf "$tmp/m"; cp -R "$tmp/pristine" "$tmp/m"
  (cd "$tmp/m" && "$@") || { err "$name: mutation didn't apply"; return; }
  out=$(cd "$tmp/m" && bash scripts/check-template.sh 2>&1); rc=$?
  if grep -q Traceback <<<"$out"; then err "$name crashes the check"
  elif [ "$rc" -ne 0 ] && grep -qF -- "$expect" <<<"$out"; then ok "$name fails the check"
  else err "$name passes the check (rc=$rc)"; fi
}
# variant NAME CMD... — the same, but the check must still pass.
variant() {
  local name=$1 rc; shift
  rm -rf "$tmp/m"; cp -R "$tmp/pristine" "$tmp/m"
  (cd "$tmp/m" && "$@") || { err "$name: change didn't apply"; return; }
  out=$(cd "$tmp/m" && bash scripts/check-template.sh 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then ok "$name passes the check"; else err "$name fails the check:"; grep FAIL <<<"$out"; fi
}
unwire_guard() {
  python3 -I -c 'import json; p = ".claude/settings.json"; d = json.load(open(p)); del d["hooks"]["PreToolUse"]; json.dump(d, open(p, "w"), indent=2)'
}
drop_ssh_deny() {
  python3 -I -c 'import json; p = ".claude/settings.json"; d = json.load(open(p)); d["permissions"]["deny"].remove("Read(~/.ssh/**)"); json.dump(d, open(p, "w"), indent=2)'
}
requote_and_delete_guard() {   # "$CLAUDE_PROJECT_DIR"/... is the style Claude Code's docs show
  python3 -I -c 'import json; p = ".claude/settings.json"; d = json.load(open(p))
for g in d["hooks"]["PreToolUse"]:
    for h in g["hooks"]:
        h["command"] = h["command"].replace("$CLAUDE_PROJECT_DIR/", "$CLAUDE_PROJECT_DIR\"/").rstrip("\"")
json.dump(d, open(p, "w"), indent=2)' && grep -q 'CLAUDE_PROJECT_DIR\\"/' .claude/settings.json &&
    rm .claude/hooks/block-dangerous.sh
}
disable_all_hooks() {
  python3 -I -c 'import json; p = ".claude/settings.json"; d = json.load(open(p)); d["disableAllHooks"] = True; json.dump(d, open(p, "w"), indent=2)'
}
move_section_6() {   # renamed header + the regression §6 exists to catch
  sed -i.bak -e 's/^echo "== 6\. /echo "== 6 /' -e '/^  hits=/s/git grep -nIE -e /git grep -nIE /' scripts/check-template.sh &&
    grep -q '^echo "== 6 ' scripts/check-template.sh
}
local_only_ref() {   # an @-import of a gitignored file that only exists on the owner's machine
  printf 'local/\n' >> .gitignore && printf 'See @local/notes.md for my data.\n' > LOCAL.md && git add LOCAL.md .gitignore
}
drop_dash_e() {   # only the scan itself, not the marker §6 looks for
  sed -i.bak '/^  hits=/s/git grep -nIE -e /git grep -nIE /' scripts/check-template.sh &&
    grep -q '^  hits=$(git grep -nIE "' scripts/check-template.sh
}

echo "== mutations"
mutant "deleted guard script" "block-dangerous.sh is missing" rm .claude/hooks/block-dangerous.sh
mutant "unwired guard" "does not wire an existing block-dangerous.sh" unwire_guard
mutant "guard deleted, wired as \"\$CLAUDE_PROJECT_DIR\"/..." "block-dangerous.sh is missing" requote_and_delete_guard
mutant "disableAllHooks" "sets disableAllHooks" disable_all_hooks
mutant "§6 header moved, -e dropped" 'the "== 6." header moved' move_section_6
mutant "non-executable status line" "statusline.sh is not executable" chmod -x .claude/statusline.sh
mutant "secret scan without -e" "secret-content scan uses -e" drop_dash_e
mutant "no ~/.ssh deny" "missing home credential stores: Read(~/.ssh/**)" drop_ssh_deny
mutant "no .gitignore" ".gitignore is missing" rm .gitignore
variant "@-import of a gitignored local-only file" local_only_ref

echo
if [ "$fail" -ne 0 ]; then echo "RESULT: FAIL"; exit 1; fi
echo "RESULT: PASS"
