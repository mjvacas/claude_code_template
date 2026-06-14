#!/usr/bin/env bash
# statusLine command — renders the bottom-of-screen status. Claude Code pipes a JSON
# event on stdin; stdout (first line) becomes the status line. Kept deliberately small
# and dependency-free (bash, python3, git). Shows: model · dir · git-branch, plus live
# signals when the event carries them — session-context tokens (absolute, vs the window
# size, with a ~200k nudge), session cost (USD), and (subscription plans only) 5-hour and
# 7-day rate-limit usage each with its reset clock time. These render to the terminal only;
# the status line never enters the model's context, so it costs zero tokens (free-local).
#
# Schema note: field names in the status event have evolved across Claude Code versions
# (e.g. model.display_name, workspace.current_dir, cost.total_cost_usd,
# context_window.used_percentage, context_window.context_window_size,
# rate_limits.five_hour.used_percentage, rate_limits.{five_hour,seven_day}.resets_at). This
# script reads them defensively and omits anything missing — adjust if your version differs.
set -euo pipefail

input=$(cat 2>/dev/null || echo '{}')

# python emits exactly three lines: model, dir basename, and the joined metrics suffix
# (any of which may be empty). Three guarded reads keep `set -e` happy if python is
# absent or prints fewer lines.
{ read -r model || true; read -r dir || true; read -r metrics || true; } <<EOF
$(printf '%s' "$input" | python3 -c '
import json, sys, os, time

try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
if not isinstance(d, dict):          # valid-but-non-object JSON (array/number/string)
    d = {}

def g(obj, *keys):
    for k in keys:
        if not isinstance(obj, dict):
            return None
        obj = obj.get(k)
    return obj

def num(x):
    # reject bool (bool is an int subclass) and non-numbers
    return x if isinstance(x, (int, float)) and not isinstance(x, bool) else None

def clean(s):
    # a stray newline in a field would shift the 3-line contract and corrupt output
    return str(s).replace("\n", " ").replace("\r", " ")

model = g(d, "model", "display_name") or g(d, "model", "id") or "?"
cwd = g(d, "workspace", "current_dir") or d.get("cwd") or os.getcwd()

ctx = num(g(d, "context_window", "used_percentage"))
size = num(g(d, "context_window", "context_window_size"))
warn200 = bool(d.get("exceeds_200k_tokens"))
cost = num(g(d, "cost", "total_cost_usd"))
rl5 = num(g(d, "rate_limits", "five_hour", "used_percentage"))
rl7 = num(g(d, "rate_limits", "seven_day", "used_percentage"))
rl5_reset = num(g(d, "rate_limits", "five_hour", "resets_at"))
rl7_reset = num(g(d, "rate_limits", "seven_day", "resets_at"))
# rate_limits present ⇒ a subscription plan, where total_cost_usd is a *notional*
# equivalent-API-cost (you pay a flat subscription, not per token), which reads as
# a charge and confuses. Hide it there — the 5h/7d windows below are the real signal.
# Pay-as-you-go events carry no rate_limits, so the cost there is real → show it.
on_subscription = isinstance(d.get("rate_limits"), dict)

def toks(n):                                # compact token count: 152000→"152k", 1000000→"1M"
    n = int(round(n))
    if n >= 1_000_000 and n % 1_000_000 == 0:
        return "%dM" % (n // 1_000_000)
    if n >= 1000:
        return "%dk" % round(n / 1000.0)
    return "%d" % n

def clock(ts, with_day):                    # epoch seconds → local wall-clock "16:30"/"Tue 16:30"
    if not (1_000_000_000 <= ts <= 10_000_000_000):   # reject ms-vs-seconds mix / absurd values
        return None
    try:
        return time.strftime("%a %H:%M" if with_day else "%H:%M", time.localtime(ts))
    except (OverflowError, OSError, ValueError):       # never let a bad ts blank the whole line
        return None

segs = []
# Session context — resettable per conversation (a /clear or handoff resets it). Show
# absolute in-window tokens against the window size, and nudge at the fixed ~200k mark
# where long-context quality degrades — independent of window size, so a 1M-context
# model still warns (a raw % would not trip 80% until 800k). Derive the absolute count
# from used_percentage × size: version-robust (total_input_tokens was a cumulative
# session total before v2.1.132).
if ctx is not None and size is not None:
    used = ctx / 100.0 * size
    flag = "⚠ " if (used >= 200_000 or warn200) else ""
    segs.append(flag + "ctx %s/%s" % (toks(used), toks(size)))
elif ctx is not None:                       # size missing — fall back to a percentage
    p = int(round(ctx))
    segs.append(("⚠ " if (p >= 80 or warn200) else "") + "ctx %d%%" % p)
elif warn200:                               # no % and no size — fixed-threshold flag only
    segs.append("⚠ >200k ctx")
if cost is not None and not on_subscription:
    segs.append("~$%.2f" % cost)            # ~ flags estimate (computed at API list prices)
# Budget windows — cumulative rate-limit allowance; survive a session-context clear.
# Subscription plans only; absent for API use, and each window can be independently absent.
if rl5 is not None:
    p = int(round(rl5))
    seg = ("⚠ " if p >= 80 else "") + "5h %d%%" % p
    r = clock(rl5_reset, False) if rl5_reset is not None else None
    if r:                                   # append reset clock only when renderable
        seg += " (%s)" % r
    segs.append(seg)
if rl7 is not None:
    p = int(round(rl7))
    seg = ("⚠ " if p >= 80 else "") + "7d %d%%" % p
    r = clock(rl7_reset, True) if rl7_reset is not None else None
    if r:
        seg += " (%s)" % r
    segs.append(seg)

print(clean(model))
print(clean(os.path.basename(cwd) or "/"))
print(clean(" · ".join(segs)))
' 2>/dev/null || true)
EOF

model="${model:-?}"
dir="${dir:-.}"
branch=$(git branch --show-current 2>/dev/null || echo "")

line="${model} · ${dir}"
[ -n "$branch" ] && line="$line · ⎇ $branch"
[ -n "$metrics" ] && line="$line · $metrics"
printf '%s\n' "$line"
