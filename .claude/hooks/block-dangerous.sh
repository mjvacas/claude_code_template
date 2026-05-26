#!/usr/bin/env bash
# PreToolUse(Bash) guard — hard-blocks a small set of catastrophic, irreversible
# shell commands. This is the ONLY 100%-enforced, blockable layer: CLAUDE.md guidance
# is followed ~80% of the time and `ask` rules can be click-accepted, but a deny here
# cannot be overridden by the model. It receives the tool-call event as JSON on stdin.
#
# IT IS A SAFETY NET, NOT A SANDBOX. A determined model can rephrase around any regex
# (env-var indirection like `X=/; rm -rf "$X"`, base64, or write-a-script-then-run-it).
# This is defense-in-depth on top of the `ask` rules and the lockdown overlay / OS
# sandbox — not a replacement. Patterns are deliberately NARROW (anchored to the rm
# command, only root/home/parent targets) so false positives stay near zero; a guard
# that cries wolf gets disabled. See docs/skill-security.md.
#
# Block contract: we print a deny JSON to stdout AND `exit 2` with a stderr reason, so
# the block holds on both older (exit-code) and newer (JSON permissionDecision) Claude
# Code versions. Neither path lets a matched command through.
set -euo pipefail

input=$(cat)
tool=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_name",""))' 2>/dev/null || echo "")
[ "$tool" = "Bash" ] || exit 0
cmd=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || echo "")
[ -n "$cmd" ] || exit 0

deny() {
  local reason="blocked by block-dangerous.sh: $1"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "$(printf '%s' "$reason" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
  printf 'BLOCKED: %s\n' "$1" >&2
  exit 2
}

# Block only when matched; the `if ... grep -q` form is safe under `set -e`/pipefail.
block_if() { if printf '%s' "$cmd" | grep -Eq "$1"; then deny "$2"; fi; }

# rm of root / home / parent — NOT ./build, dist, node_modules, "$TMPDIR/x" (those pass;
# the existing `ask: rm` rule still prompts on them). Target is anchored to the rm command.
block_if '(^|[^[:alnum:]_-])rm([[:space:]]+-{1,2}[A-Za-z-]+)*[[:space:]]+((/|~|\$HOME)(/?\*?)?|\.\.)([[:space:]]|;|&|\||$)' \
  'rm targeting / ~ \$HOME /* or .. — refusing catastrophic recursive delete'

# git: history- and worktree-destroying operations
block_if '(^|[^[:alnum:]_-])git[[:space:]]+reset[[:space:]].*--hard' \
  'git reset --hard (discards working changes irreversibly)'
block_if '(^|[^[:alnum:]_-])git[[:space:]]+push[[:space:]]+([^[:space:]]+[[:space:]]+)*(--force[a-z-]*|-f)([[:space:]]|=|$)' \
  'git push --force / --force-with-lease / -f (rewrites remote history)'
block_if '(^|[^[:alnum:]_-])git[[:space:]]+clean[[:space:]].*(-[A-Za-z]*f[A-Za-z]*d|-[A-Za-z]*d[A-Za-z]*f|-d[[:space:]].*-f|-f[[:space:]].*-d|--force.*-d|-d.*--force)' \
  'git clean -fd (permanently deletes untracked files)'

# remote-code execution and disk/permission wipes
block_if '(curl|wget)[[:space:]].*\|[[:space:]]*(sudo[[:space:]]+)?[a-z]*sh([[:space:]]|-|$)' \
  'pipe-to-shell (curl|sh) — runs unreviewed remote code'
block_if 'chmod[[:space:]].*(-R|--recursive)[[:space:]]+0*777' \
  'chmod -R 777 (world-writable, recursive)'
block_if '(^|[^[:alnum:]_-])dd[[:space:]].*of=/dev/' \
  'dd writing to a device — can wipe a disk'
block_if '(^|[^[:alnum:]_-])mkfs(\.[a-z0-9]+)?[[:space:]]' \
  'mkfs — formats a filesystem'
block_if ':\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:' \
  'fork bomb'

exit 0
