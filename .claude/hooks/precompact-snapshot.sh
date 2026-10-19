#!/usr/bin/env bash
# PreCompact hook — fires just before Claude Code compacts the conversation: automatically
# near the context limit or after a long conversation sits idle (see the template's
# docs/token-awareness.md → Compaction), or on manual /compact. Compaction replaces the
# in-context history with a summary; this writes a durable breadcrumb to disk first so the
# session's recent state survives: a pointer to the append-only transcript (the de-facto
# write-ahead log Claude Code already keeps) plus a tail of the most recent turns.
#
# This is a SAFETY NET for compaction/crash recovery — NOT a substitute for /handoff.
# Promote anything worth keeping into AI_CONTEXT.md. A PreCompact hook's stdout is added to
# the summarizer's instructions, so this prints only to stderr; the value is the file it
# writes. Snapshots land in .claude/snapshots/ (gitignored — they hold raw conversation,
# possibly secrets), owner-only, newest 20 kept. The hook ALWAYS exits 0: a snapshot failure
# must never block compaction.
set -uo pipefail

input=$(cat 2>/dev/null || echo '{}')
dir="${CLAUDE_PROJECT_DIR:-.}/.claude/snapshots"
umask 077   # raw conversation: owner-only (dir 700, files 600)
mkdir -p "$dir" 2>/dev/null || exit 0
chmod 700 "$dir" 2>/dev/null || true   # a directory made before this fix

out=$(EVENT_JSON="$input" python3 -I - "$dir" <<'PY'
import json, os, re, sys, datetime

try:
    event = json.loads(os.environ.get("EVENT_JSON", "") or "{}")
except Exception:
    event = {}

outdir = sys.argv[1]
tpath = event.get("transcript_path", "")
trigger = event.get("trigger", "?")
sid = event.get("session_id", "")
now = datetime.datetime.now()

# Pull the last few human-readable turns from the append-only transcript JSONL.
turns = []
if tpath and os.path.exists(tpath):
    with open(tpath, encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            if not isinstance(obj, dict):
                continue
            msg = obj.get("message") if isinstance(obj.get("message"), dict) else obj
            role = msg.get("role") or obj.get("type")
            if role not in ("user", "assistant"):
                continue
            content = msg.get("content")
            if isinstance(content, str):
                text = content
            elif isinstance(content, list):
                text = " ".join(
                    b.get("text", "") for b in content
                    if isinstance(b, dict) and b.get("type") == "text"
                )
            else:
                text = ""
            text = text.strip()
            if text:
                turns.append((role, text))
turns = turns[-16:]

stamp = now.strftime("%Y-%m-%dT%H-%M-%S")
path = os.path.join(outdir, f"{stamp}-{(sid[:8] or 'session')}.md")
with open(path, "w", encoding="utf-8") as o:
    o.write("# Pre-compaction snapshot\n\n")
    o.write(f"- When: {now.isoformat(timespec='seconds')}\n")
    o.write(f"- Trigger: {trigger} compaction\n")
    o.write(f"- Session: {sid or '(unknown)'}\n")
    o.write(f"- Full transcript (append-only WAL): {tpath or '(unknown)'}\n\n")
    o.write("> Auto-written before compaction. Recover full detail from the transcript "
            "above; promote anything worth keeping into AI_CONTEXT.md via /handoff.\n\n")
    o.write(f"## Last {len(turns)} turn(s)\n\n")
    for role, text in turns:
        if len(text) > 800:
            text = text[:800].rstrip() + " …[truncated]"
        o.write(f"**{role}:** {text}\n\n")
print(path)

# Keep the one just written plus the newest KEEP-1 others, by modification time (names use
# local time, which a timezone change reorders), touching only files named the way this
# hook names them. Kept ones written before the umask fix heal to 600. Errors go to stderr,
# one file at a time, so one bad file doesn't stop the rest.
KEEP = 20
def mtime(f):
    try:
        return os.path.getmtime(os.path.join(outdir, f))
    except OSError:
        return 0
others = sorted((f for f in os.listdir(outdir) if f != os.path.basename(path)
                 and re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d-\d\d-\d\d-[^/]+\.md", f)),
                key=lambda f: (mtime(f), f))
cut = max(0, len(others) - (KEEP - 1))
for f in others[:cut]:
    try:
        os.remove(os.path.join(outdir, f))
    except OSError as e:
        print(f"precompact-snapshot: can't prune {f}: {e}", file=sys.stderr)
for f in others[cut:]:
    try:
        os.chmod(os.path.join(outdir, f), 0o600)
    except OSError as e:
        print(f"precompact-snapshot: can't make {f} owner-only: {e}", file=sys.stderr)
PY
) || true

[ -n "${out:-}" ] && printf 'context snapshot written: %s\n' "$out" >&2
exit 0
