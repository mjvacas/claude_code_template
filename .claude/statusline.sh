#!/usr/bin/env bash
# statusLine command — renders the bottom-of-screen status. Claude Code pipes a JSON
# event on stdin; stdout (first line) becomes the status line. Kept deliberately small
# and dependency-free (bash, python3, git). Shows: model · dir · git-branch, plus live
# signals when the event carries them — context-window fill %, session cost (USD), and
# (subscription plans only) 5-hour rate-limit usage. These render to the terminal only;
# the status line never enters the model's context, so it costs zero tokens (free-local).
#
# Schema note: field names in the status event have evolved across Claude Code versions
# (e.g. model.display_name, workspace.current_dir, cost.total_cost_usd,
# context_window.used_percentage, rate_limits.five_hour.used_percentage). This script
# reads them defensively and omits anything missing — adjust if your version differs.
set -euo pipefail

input=$(cat 2>/dev/null || echo '{}')

# python emits exactly three lines: model, dir basename, and the joined metrics suffix
# (any of which may be empty). Three guarded reads keep `set -e` happy if python is
# absent or prints fewer lines.
{ read -r model || true; read -r dir || true; read -r metrics || true; } <<EOF
$(printf '%s' "$input" | python3 -c '
import json, sys, os

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
warn200 = bool(d.get("exceeds_200k_tokens"))
cost = num(g(d, "cost", "total_cost_usd"))
rl5 = num(g(d, "rate_limits", "five_hour", "used_percentage"))
# rate_limits present ⇒ a subscription plan, where total_cost_usd is a *notional*
# equivalent-API-cost (you pay a flat subscription, not per token), which reads as
# a charge and confuses. Hide it there — the 5h%% below is the real constraint.
# Pay-as-you-go events carry no rate_limits, so the cost there is real → show it.
on_subscription = isinstance(d.get("rate_limits"), dict)

segs = []
if ctx is not None:                         # real fill % beats the fixed 200k flag
    p = int(round(ctx))
    segs.append(("⚠ " if p >= 80 else "") + "ctx %d%%" % p)
elif warn200:                               # fallback only when % is unavailable
    segs.append("⚠ >200k ctx")
if cost is not None and not on_subscription:
    segs.append("~$%.2f" % cost)            # ~ flags estimate (computed at API list prices)
if rl5 is not None:                         # subscription plans only; absent for API use
    p = int(round(rl5))
    segs.append(("⚠ " if p >= 80 else "") + "5h %d%%" % p)

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
