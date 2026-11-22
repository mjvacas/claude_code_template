#!/usr/bin/env bash
# compaction-report.sh — list recent Claude Code compactions from your local session
# transcripts: when, which project, how large the context was, and how long the session
# had been idle first. Idle compaction summarizes a long conversation left alone for about
# 54 minutes, before its prompt cache expires; this shows how often that happened to you.
# See docs/token-awareness.md → Compaction.
#
# Read-only. Prints metadata only, never message text. Transcripts are Claude Code's
# internal format and can change between versions; this reads type, subtype, timestamp,
# isMeta, isSidechain, isCompactSummary, cwd, version, the text of system notices, and
# compactMetadata.{trigger,preTokens,durationMs}. Before 2.1.290, idle compactions were
# recorded with trigger "manual", so the idle column is what tells them apart.
#
# Usage:
#   scripts/compaction-report.sh               # last 7 days, every project
#   scripts/compaction-report.sh --days 30
#   scripts/compaction-report.sh --root DIR    # default: ${CLAUDE_CONFIG_DIR:-~/.claude}/projects
set -uo pipefail

root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
days=7
while [ $# -gt 0 ]; do
  case $1 in
    --root|--days)
      [ $# -ge 2 ] || { echo "compaction-report: $1 needs a value" >&2; exit 2; }
      if [ "$1" = --root ]; then root=$2; else days=$2; fi
      shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "compaction-report: unknown argument: $1" >&2; exit 2 ;;
  esac
done
case $days in ''|*[!0-9]*) echo "compaction-report: --days needs a whole number" >&2; exit 2 ;; esac
[ -d "$root" ] || { echo "compaction-report: no such directory: $root" >&2; exit 2; }

python3 -I - "$root" "$days" <<'PY'
import glob, json, os, sys, time
from datetime import datetime, timezone

root, days = sys.argv[1], int(sys.argv[2])
cutoff = time.time() - days * 86400
NOTICES = ("Compacted while idle", "Compacted after an hour idle")

def when(s):
    try:   # first 19 chars: python 3.9's fromisoformat rejects the trailing Z
        return datetime.strptime(str(s)[:19], "%Y-%m-%dT%H:%M:%S").replace(tzinfo=timezone.utc)
    except ValueError:
        return None

paths = glob.glob(os.path.join(glob.escape(root), "*", "*.jsonl"))
if not paths:   # a wrong --root would otherwise read as "No compactions"
    print(f"compaction-report: no */*.jsonl transcripts under {root}; --root should be "
          "Claude Code's projects directory", file=sys.stderr)
    sys.exit(2)
rows = []   # [time, project, trigger, tokens, idle minutes, version, flag]
unread = 0  # compaction records whose timestamp couldn't be parsed
for path in paths:
    if os.path.getmtime(path) < cutoff:
        continue
    last = row = None   # last real activity; the compaction a notice would belong to
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if not isinstance(d, dict):
                continue
            t = when(d.get("timestamp"))
            kind = (d.get("type"), d.get("subtype"))
            if kind == ("system", "compact_boundary") and not t:
                unread += 1
            elif kind == ("system", "compact_boundary"):
                cm = d.get("compactMetadata") if isinstance(d.get("compactMetadata"), dict) else {}
                dur = cm.get("durationMs")
                # The record is written when compaction ends; measure idle time to its start.
                start = t.timestamp() - (dur / 1000 if isinstance(dur, (int, float)) else 0)
                idle = (start - last.timestamp()) / 60 if last else None
                project = os.path.basename(str(d.get("cwd") or "")) or os.path.basename(os.path.dirname(path))
                flag = "likely idle (gap)" if idle is not None and 50 <= idle <= 60 else ""
                row = [t, project, cm.get("trigger", "?"), cm.get("preTokens"), idle, d.get("version", "?"), flag]
                if t.timestamp() >= cutoff:
                    rows.append(row)
            elif kind == ("system", "informational") and row is not None:
                if isinstance(d.get("content"), str) and d["content"].startswith(NOTICES):
                    row[6] = "idle (notice)"
            elif d.get("type") in ("user", "assistant") and t and not (
                    d.get("isMeta") or d.get("isSidechain") or d.get("isCompactSummary")):
                last, row = t, None

if unread:
    print(f"compaction-report: skipped {unread} compaction record(s) with an unreadable "
          "timestamp; the transcript format may have changed", file=sys.stderr)
if not rows:
    print(f"No compactions in the last {days} day(s) under {root}")
    sys.exit(0)
rows.sort(key=lambda r: r[0])
print(f"{'time':16}  {'project':24}  {'trigger':7}  {'tokens':>9}  {'idle min':>8}  {'version':9}  flag")
for t, project, trigger, tokens, idle, version, flag in rows:
    tok = f"{tokens:,}" if isinstance(tokens, int) else "?"
    gap = f"{idle:.1f}" if idle is not None else "?"
    print(f"{t.astimezone().strftime('%Y-%m-%d %H:%M'):16}  {project[:24]:24}  {str(trigger)[:7]:7}  "
          f"{tok:>9}  {gap:>8}  {str(version)[:9]:9}  {flag}")
by_notice = sum(r[6] == "idle (notice)" for r in rows)
by_gap = sum(r[6] == "likely idle (gap)" for r in rows)
print(f"\n{len(rows)} compaction(s); {by_notice + by_gap} idle ({by_notice} by notice, {by_gap} by gap)")
PY
