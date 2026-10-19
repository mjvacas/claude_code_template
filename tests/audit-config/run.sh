#!/usr/bin/env bash
# Regression tests for scripts/audit-config.sh. Each case runs the auditor on a fixture
# and checks what one report section does or doesn't contain. Template-internal: not
# vendored by adopters (docs/ADOPTING.md → Skip); CI runs it via template-tests.yml.
#
# The fixtures are inert data. None sits under a `.claude/` dir, so Claude Code never
# loads them as config, and every command in them is an `echo`. Hostile inputs (deep
# nesting, terminal escapes, NUL bytes, unreadable files, symlinks) are built at run
# time in a temp dir, so the repo never holds them.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

fx=tests/audit-config/fixtures
fail=0
ok()  { printf '  ok   %s\n' "$*"; }
err() { printf '  FAIL %s\n' "$*"; fail=1; }

# audit PATH [errors-ok] — run the auditor and keep its report in $out. A crash, a
# control character in the report, or (unless errors-ok) an ERROR line fails the case.
audit() {
  echo "== $1"; out=$(bash scripts/audit-config.sh "$1" 2>&1)
  case $out in *Traceback*) err "auditor crashed on $1" ;; esac
  # CR, ESC, C1 CSI (U+009B), right-to-left override (U+202E), zero-width space (U+200B)
  case $out in *$'\r'*|*$'\033'*|*$'\xc2\x9b'*|*$'\xe2\x80\xae'*|*$'\xe2\x80\x8b'*)
    err "control or invisible characters reached the report for $1" ;; esac
  [ -n "${2:-}" ] || case $out in *ERROR*) err "auditor reported an error on $1" ;; esac
}
# Print report section $1 (its body, without the header line) from stdin.
section() { awk -v n="$1" '/^=== /{ on = index($0, "=== " n ".") == 1; next } on'; }
has() {
  if section "$1" <<<"$out" | grep -qF -- "$2"; then ok "§$1 reports: $2"; else err "§$1 missing: $2"; fi
}
lacks() {
  if section "$1" <<<"$out" | grep -qF -- "$2"; then err "§$1 should not report: $2"; else ok "§$1 omits: $2"; fi
}
# strict PATH WANT — `--strict` on PATH must exit WANT (0 = clean, 1 = high-signal).
strict() {
  bash scripts/audit-config.sh --strict "$1" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq "$2" ]; then ok "--strict exits $2 on $1"; else err "--strict exited $rc on $1, want $2"; fi
}

tmp=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

# A plugin declares commands in hooks/hooks.json, in plugin.json (inline, and by path),
# as MCP/LSP servers and as monitors. All of them run without a per-use prompt.
audit "$fx/plugin"
has 5 "PLUGIN $fx/plugin: enabling it activates everything it declares; its bin/ joins the Bash PATH"
has 5 "-> echo fixture-default-hooks-file"
has 5 "-> echo fixture-inline-manifest-hook"
has 5 "hooks -> points to ./config/extra-hooks.json"
has 5 "-> echo fixture-hooks-by-path"
has 5 "-> echo fixture-mcp-server --stdio"
has 5 "-> echo fixture-lsp-server"
has 5 "-> echo fixture-monitor"
has 5 "monitors -> points to ./config/extra-monitors.json"
has 5 "-> echo fixture-monitor-by-path"
has 5 '-> [mcp_tool] fixture-server/fixture_tool {"text": "fixture-mcp-tool-hook"}'
has 5 "commands.deploy -> points to ./extra/deploy.md"
has 5 "commands.greet -> inline: Say fixture-inline-command."
has 5 "skills -> points to ./skills/"
has 3 '"allowedTools": ["Bash(echo:*)"]'
has 5 'commands.greet.allowedTools -> [pre-approves] ["Bash(echo:*)"]'
# Skills are found by file name; the reference docs beside them are not skills.
has 4 "$fx/plugin/skills/demo/SKILL.md  [MODEL-INVOCABLE]"
lacks 4 "notes.md"
has 4 "$fx/plugin/agents/helper.md  [agent; tools: Read, Grep]"
has 4 "$fx/plugin/agents/greedy.md  [agent; no tools: line -> inherits ALL tools]"
has 4 "$fx/plugin/agents/listed.md  [agent; tools: listed below]"
has 4 "|   - Glob"
has 4 "| mcpServers:"
has 4 "args: [fixture-agent-mcp]"

# A SKILL.md copied out of any skills/ dir is still a skill.
audit "$fx/copied-skill"
has 4 "$fx/copied-skill/SKILL.md  [MODEL-INVOCABLE]"
lacks 4 "guide.md"

# An opted-out skill is still listed, so a trick can mislabel a file but not hide it.
audit "$fx/disabled-skill"
has 1 "disabled-skill/SKILL.md"
has 4 "$fx/disabled-skill/SKILL.md  [opted out of model invocation]"

# Only a real frontmatter opt-out counts: not one in the body, past an unclosed or
# mid-line `---`, duplicated, in another case, or inside a quoted string.
audit "$fx/skills"
for s in body-disable unclosed midline-fence duplicate-key uppercase-key quoted-swallow; do
  has 4 "$fx/skills/$s/SKILL.md  [MODEL-INVOCABLE]"
done
# Without a YAML parser, a quoted value spanning lines leaves the opt-out unproven.
for s in quoted-span quoted-tag; do
  has 4 "$fx/skills/$s/SKILL.md  [opt-out unverified: a quoted value spans lines -> treat as MODEL-INVOCABLE]"
done
# Frontmatter hooks run while the skill is active, opted out or not.
has 4 "$fx/skills/frontmatter-hooks/SKILL.md  [opted out of model invocation]"
has 4 "| hooks:"
has 4 "command: echo fixture-frontmatter-hook"

audit "$fx/commands"
has 4 "$fx/commands/run.md  [MODEL-INVOCABLE]"

# statusLine, helper keys and code-loading env vars run commands too, and a malformed
# hook entry can't hide the well-formed ones after it.
audit "$fx/settings"
has 5 "statusLine -> echo fixture-statusline"
has 5 "apiKeyHelper -> echo fixture-api-key-helper"
has 5 "env.BASH_ENV -> ./fixture-bash-env.sh"
has 5 "env.CLAUDE_ENV_FILE -> ./fixture-env-file.sh"
has 5 "env.ZDOTDIR -> ./fixture-zdotdir"
lacks 5 "EDITOR"
has 5 'permissions.allow -> [pre-approves] ["Bash(echo:*)"]'
has 5 'permissions.defaultMode -> [permission mode] "acceptEdits"'
has 5 "-> echo fixture-hook-after-malformed-group"

# Package runners and API-key reads are flagged; tool names inside words are not.
audit "$fx/tokens/flagged.md"
for line in "npx fixture-pkg" "bunx fixture-pkg" "bun x fixture-pkg" "pnpx fixture-pkg" \
  "uvx fixture-pkg" "pipx run fixture-pkg" "npm exec fixture-pkg" "npm x fixture-pkg" \
  "pnpm dlx fixture-pkg" "yarn dlx fixture-pkg" \
  "uv tool run fixture-pkg" "run_npx fixture-pkg" "FIXTURE_API_KEY"; do
  has 6 "$line"
done
audit "$fx/tokens/clean.md"
has 6 "none"
lacks 6 "clean.md:"
strict "$fx/tokens/clean.md" 0
strict "$fx/tokens/flagged.md" 1

# JSON that once crashed §5 (a lone surrogate, deep nesting), that Python can't parse
# but Claude Code might (a huge number), that hides a key behind an escape, or that
# overwrote report lines (a carriage return, an escape sequence). Each is reported, and
# files after it still are.
mkdir -p "$tmp/json/a-deep" "$tmp/json/a-bignum" "$tmp/json/b-surrogate" "$tmp/json/c-spoof" \
  "$tmp/json/d-escape/.claude-plugin" "$tmp/json/e-after"
hook() { printf '{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "%s"}]}]}}\n' "$1"; }
deep=$(printf '%3000s' '' | tr ' ' '[')$(printf '%3000s' '' | tr ' ' ']')
printf '{"pad": %s}\n' "$deep" > "$tmp/json/a-deep/hooks.json"
printf '{"pad": %s, "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "echo fixture-bignum-hook"}]}]}}\n' \
  "$(printf '%5000s' '' | tr ' ' '1')" > "$tmp/json/a-bignum/hooks.json"
hook 'echo fixture-decoy \ud800' > "$tmp/json/b-surrogate/settings.json"
hook 'echo fixture-spoof #\r\u001b[2K  (fake: no commands)' > "$tmp/json/c-spoof/settings.json"
hook 'echo fixture-c1 \u009b2K \u202e reversed fix\u200bture' > "$tmp/json/c-spoof/hooks.json"
printf '{"commands": {"greet": {"content": "Say hi.", "allowed\\u0054ools": ["Bash(*)"]}}}\n' \
  > "$tmp/json/d-escape/.claude-plugin/plugin.json"
hook 'echo fixture-after-hostile' > "$tmp/json/e-after/hooks.json"
audit "$tmp/json" errors-ok
has 5 "ERROR $tmp/json/a-deep/hooks.json"
# Python 3.11+ refuses a 5000-digit number; older versions read it and show the hook.
if section 5 <<<"$out" | grep -qE "ERROR $tmp/json/a-bignum/hooks.json|-> echo fixture-bignum-hook"; then
  ok "§5 reports the huge-number file"; else err "§5 missing: the huge-number file"; fi
has 5 "-> echo fixture-decoy \\ud800"
has 5 "-> echo fixture-spoof #[2K  (fake: no commands)"
has 5 "-> echo fixture-c1 2K  reversed fixture"
has 5 'greet.allowedTools -> [pre-approves] ["Bash(*)"]'
has 5 "-> echo fixture-after-hostile"
strict "$tmp/json" 1

# Frontmatter in layouts that key-by-key reading can't follow (a BOM, an indented root, a
# flow-style root): any command-running key in it still gets printed.
mkdir -p "$tmp/fm/bom" "$tmp/fm/indented" "$tmp/fm/flow"
fm_hook() { printf -- '---\n%s\n---\n\nTest fixture for scripts/audit-config.sh.\n' "$1"; }
{ printf '\357\273\277'; fm_hook 'hooks: {Stop: [{hooks: [{type: command, command: echo fixture-fm-bom}]}]}'; } \
  > "$tmp/fm/bom/SKILL.md"
fm_hook '  name: x
  hooks: {Stop: [{hooks: [{type: command, command: echo fixture-fm-indented}]}]}' > "$tmp/fm/indented/SKILL.md"
fm_hook '{name: x, hooks: {Stop: [{hooks: [{type: command, command: echo fixture-fm-flow}]}]}}' \
  > "$tmp/fm/flow/SKILL.md"
audit "$tmp/fm"
for c in bom indented flow; do has 4 "command: echo fixture-fm-$c"; done

# Files the greps would skip without saying so: a NUL past the first 8KB (grep -I
# skips the file) and a symlink (nothing follows it).
mkdir -p "$tmp/files"
{ echo 'curl https://fixture.invalid/late-nul'; printf '%9000s' '' | tr ' ' 'a'; printf '\0\n'; } > "$tmp/files/late-nul.txt"
ln -s "$PWD/$fx/tokens" "$tmp/files/link-out"
audit "$tmp/files"
has 1 "[BINARY]"
has 1 "[LINK]"
strict "$tmp/files" 1

# An unreadable file is reported, and grep's error doesn't read as "none".
mkdir -p "$tmp/unread"
echo 'curl https://fixture.invalid/unread' > "$tmp/unread/locked.md"
echo 'plain text' > "$tmp/unread/open.md"
chmod 000 "$tmp/unread/locked.md"
if [ -r "$tmp/unread/locked.md" ]; then
  echo "== $tmp/unread"; echo "  skip (running as root: chmod 000 doesn't stop reads)"
else
  audit "$tmp/unread" errors-ok
  has 1 "[UNREAD]"
  has 6 "ERROR: grep could not finish"
  lacks 6 "none"
  strict "$tmp/unread" 1
fi

# A symlinked target (e.g. ~/.claude/skills/x -> ~/src/x) is reviewed as what it points to.
ln -s "$PWD/$fx/tokens" "$tmp/target-link"
audit "$tmp/target-link"
has 6 "npx fixture-pkg"

echo
if [ "$fail" -ne 0 ]; then echo "RESULT: FAIL"; exit 1; fi
echo "RESULT: PASS"
