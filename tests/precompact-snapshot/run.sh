#!/usr/bin/env bash
# Regression tests for .claude/hooks/precompact-snapshot.sh: the snapshot it writes is
# owner-only, old snapshots are pruned to the newest 20 (and nothing else in the directory
# is touched), message text comes from the transcript, and the hook never fails, even
# without python3. Template-internal: not vendored by adopters (docs/ADOPTING.md → Skip);
# CI runs it via template-tests.yml.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

hook="$PWD/.claude/hooks/precompact-snapshot.sh"
fail=0
ok()  { printf '  ok   %s\n' "$*"; }
err() { printf '  FAIL %s\n' "$*"; fail=1; }
mode() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }   # GNU first: GNU reads -f as --file-system

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
snaps="$tmp/.claude/snapshots"
mkdir -p "$snaps" && chmod 755 "$snaps"
# 25 snapshots from before the fix (world-readable), plus a file the hook must leave alone.
for i in $(seq -w 1 25); do printf 'old\n' > "$snaps/2026-01-01T00-00-$i-oldsnaps.md"; done
chmod 644 "$snaps"/*.md
printf 'keep me\n' > "$snaps/notes.txt"
# A transcript with a turn to quote and lines the hook must skip (not JSON, not an object).
transcript="$tmp/transcript.jsonl"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"FIXTURE-MESSAGE-TEXT"}}' 'not json' '[]' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"reply"}]}}' > "$transcript"
event=$(printf '{"trigger":"auto","session_id":"abcdef1234","transcript_path":"%s"}' "$transcript")

echo "== with python3"
(umask 022; CLAUDE_PROJECT_DIR="$tmp" bash "$hook" <<<"$event" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && ok "exits 0" || err "exited $rc"
new=$(ls "$snaps" | grep -- '-abcdef12\.md$')
[ -n "$new" ] && ok "wrote $new" || err "no new snapshot"
n=$(ls "$snaps" | grep -c '\.md$')
[ "$n" -eq 20 ] && ok "kept the newest 20 snapshots" || err "kept $n snapshots, want 20"
[ -e "$snaps/2026-01-01T00-00-01-oldsnaps.md" ] && err "oldest snapshot not pruned" || ok "pruned the oldest"
[ -e "$snaps/2026-01-01T00-00-25-oldsnaps.md" ] && ok "kept the newest old one" || err "pruned a snapshot it should keep"
[ "$(cat "$snaps/notes.txt")" = "keep me" ] && [ "$(mode "$snaps/notes.txt")" = 644 ] &&
  ok "left notes.txt alone" || err "touched notes.txt"
[ "$(mode "$snaps")" = 700 ] && ok "directory is 700" || err "directory is $(mode "$snaps")"
bad=$(for f in "$snaps"/*.md; do [ "$(mode "$f")" = 600 ] || echo "$f"; done)
[ -z "$bad" ] && ok "every snapshot is 600" || err "not 600: $bad"
if [ -n "$new" ] && grep -q 'Trigger: auto' "$snaps/$new" && grep -q 'FIXTURE-MESSAGE-TEXT' "$snaps/$new"; then
  ok "records the trigger and the recent turns"; else err "snapshot content is missing the trigger or turns"; fi

echo "== newer-named snapshots (a timezone change) don't push out the new one"
snaps2="$tmp/tz/.claude/snapshots"; mkdir -p "$snaps2"
for i in $(seq -w 1 20); do printf 'later\n' > "$snaps2/2099-12-31T23-59-$i-later.md"; done
(CLAUDE_PROJECT_DIR="$tmp/tz" bash "$hook" <<<"$event" 2>/dev/null)
ls "$snaps2" | grep -q -- '-abcdef12\.md$' && ok "kept the snapshot it just wrote" || err "pruned the snapshot it just wrote"
n=$(ls "$snaps2" | grep -c '\.md$')
[ "$n" -eq 20 ] && ok "still keeps 20" || err "keeps $n, want 20"

echo "== without python3"
mkdir -p "$tmp/nopy"
for t in cat mkdir chmod; do ln -s "$(command -v "$t")" "$tmp/nopy/$t"; done
(PATH="$tmp/nopy" CLAUDE_PROJECT_DIR="$tmp" "$(command -v bash)" "$hook" <<<"$event" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && ok "exits 0" || err "exited $rc"

echo
if [ "$fail" -ne 0 ]; then echo "RESULT: FAIL"; exit 1; fi
echo "RESULT: PASS"
