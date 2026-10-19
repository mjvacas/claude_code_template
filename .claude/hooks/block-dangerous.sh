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
# Code versions. Neither path lets a matched command through. Regression cases live in
# the template repo's tests/block-dangerous/cases.txt.
set -euo pipefail

input=$(cat)
# Decode the command with python3. If python3 is missing or broken (a Mac without the
# Xcode tools has a stub that just fails), pull "command" out of the raw JSON with sed
# instead, so the guard degrades rather than silently allowing everything. Newlines
# become `;`, which every pattern below already treats as a command boundary.
if ! cmd=$(printf '%s' "$input" | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("tool_input", {}).get("command", "") if d.get("tool_name") == "Bash" else "")' 2>/dev/null); then
  printf '%s' "$input" | grep -E '"tool_name"[[:space:]]*:[[:space:]]*"Bash"' >/dev/null || exit 0
  cmd=$(printf '%s' "$input" \
    | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' \
    | sed -e 's/\\\\\\n//g' -e 's/\\"/"/g' -e 's#\\/#/#g' -e 's/\\\\/\\/g' -e 's/\\n/;/g' -e 's/\\[rt]/ /g')
fi
# Bash joins a backslash-newline continuation into one line; grep reads line by line.
cmd=${cmd//"\\"$'\n'/}
[ -n "$cmd" ] || exit 0

deny() {
  local reason
  reason=$(printf '%s' "blocked by block-dangerous.sh: $1" | sed 's/[\\"]/\\&/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
  printf 'BLOCKED: %s\n' "$1" >&2
  exit 2
}

# Block only when matched; the `if ... grep` form is safe under `set -e`/pipefail. No
# `grep -q`: it exits at the first match, printf then dies of SIGPIPE on a long command,
# and under pipefail the pipeline reads as "no match".
block_if() { if printf '%s' "$cmd" | grep -E "$1" >/dev/null; then deny "$2"; fi; }

# rm of root / home / parent — NOT ./build, dist, node_modules, "$TMPDIR/x" (those pass;
# the existing `ask: rm` rule still prompts on them). Any argument of the rm command counts,
# so `rm -rf ./build /` (a stray space) is caught too.
block_if '(^|[^[:alnum:]_-])rm([[:space:]]+[^[:space:];&|]+)*[[:space:]]+((/|~|\$HOME|\$\{HOME\})(/?\*?)?|\.\./?)([[:space:]]|;|&|\||\)|$)' \
  'rm targeting / ~ $HOME /* or .. — refusing catastrophic recursive delete'
# The same targets in quotes. Both quotes are required, so `echo "rm -rf /"` still passes;
# a quoted "~" names a literal directory called ~, so it passes too.
q="[\"']"
block_if '(^|[^[:alnum:]_-])rm([[:space:]]+[^[:space:];&|]+)*[[:space:]]+("\$(HOME|\{HOME\})/?"|'"$q"'(/|\.\.)/?'"$q"')(/?\*?)?([[:space:]]|;|&|\||\)|$)' \
  'rm targeting a quoted $HOME, / or .. — refusing catastrophic recursive delete'

# git: history- and worktree-destroying operations
block_if '(^|[^[:alnum:]_-])git[[:space:]]+reset[[:space:]].*--hard' \
  'git reset --hard (discards working changes irreversibly)'
# `git [-C dir | -c k=v | --opt] push`, then arguments that stop at ; & |
gp='(^|[^[:alnum:]_-])git([[:space:]]+(-[Cc][[:space:]]+[^[:space:];&|]+|--[a-z-]+(=[^[:space:];&|]+)?))*[[:space:]]+push'
arg='[[:space:]]+[^[:space:];&|]+'
end='([[:space:]]|=|;|&|\||\)|$)'
block_if "$gp($arg)*[[:space:]]+(--force[a-z-]*|-[[:alnum:]]*f[[:alnum:]]*|\+[^[:space:];&|]+|--mirror|--prune)$end" \
  'git push --force / -f / +ref / --mirror / --prune (rewrites or deletes remote history)'
# Deleting main/master on the remote. Other branch deletions stay prompt-only (`ask: git push`).
br='(refs/heads/)?(main|master)'
block_if "$gp(($arg)*[[:space:]]+(-d|--delete)($arg)*[[:space:]]+$br|($arg)*[[:space:]]+$br($arg)*[[:space:]]+(-d|--delete)|($arg)*[[:space:]]+:$br)$end" \
  'git push deleting main/master on the remote'
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
