#!/usr/bin/env bash
# audit-config.sh — report what Claude Code config in a path ACTUALLY does, so you
# can vet a skill / command / agent / hook / plugin before trusting it.
#
# This is a REVIEW AID for a human, not a pass/fail gate: legitimate config trips
# many of these checks (our own commands use `!`git ...`` and our hooks mention curl).
# Read the report, then decide. Pairs with docs/skill-security.md (the checklist).
#
# Handles arbitrary filenames safely (spaces/newlines via -print0) and scans EVERY
# file regardless of extension, so a payload can't hide behind an odd name (`evil cmd.md`)
# or an unusual/absent extension (`setup.ts`, an extensionless binary).
#
# Usage:
#   scripts/audit-config.sh [PATH]            # default: .claude
#   scripts/audit-config.sh path/to/SKILL.md  # a single candidate skill
#   scripts/audit-config.sh --strict [PATH]   # exit 1 if any HIGH-signal finding
set -uo pipefail

# Untrusted files can hold terminal escapes and carriage returns that would overwrite
# lines of this report. Run the report through a filter that deletes control characters
# (tabs and newlines are kept), with errors merged in so none go unseen.
if [ -z "${AUDIT_CONFIG_FILTERED:-}" ]; then
  AUDIT_CONFIG_FILTERED=1 bash "$0" "$@" 2>&1 | LC_ALL=C tr -d '\000-\010\013-\037\177'
  exit "${PIPESTATUS[0]}"
fi

strict=0
[ "${1:-}" = "--strict" ] && { strict=1; shift; }
cd "$(dirname "$0")/.." || exit 1
target="${1:-.claude}"
[ -e "$target" ] || { echo "audit-config: no such path: $target" >&2; exit 2; }
# Review a symlinked target (e.g. ~/.claude/skills/x -> ~/src/x) as what it points to:
# find and BSD grep don't descend into a link.
[ -L "$target" ] && target=$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$target")

high=0
hdr() { printf '\n=== %s ===\n' "$*"; }

# grep the target with flags/pattern "$@". grep exits 1 for no match but 2 when it can't
# read a file or use the pattern, so an error is reported (and counts as HIGH) instead of
# reading as "none". Returns 0 when something matched. LC_ALL=C so text with invalid
# UTF-8 isn't taken for binary and skipped by -I.
scan() {
  LC_ALL=C grep -rnI "$@" -- "$target"
  case $? in
    0) return 0 ;;
    1) echo "  none" ;;
    *) echo "  ERROR: grep could not finish (unreadable file or unsupported pattern) -> INCOMPLETE"; high=1 ;;
  esac
  return 1
}

# Binary = has a NUL byte anywhere, or >30% non-printable bytes in the first 8KB. Catches
# compiled binaries (NUL-heavy) and high-entropy blobs; tolerant of normal UTF-8 text/source.
# The whole file is checked because grep -I skips a file with a NUL, so §2 and §6 would
# never read it. Exit 2 = couldn't read the file.
is_binary() {
  python3 - "$1" <<'PY' 2>/dev/null
import sys
try:
    with open(sys.argv[1], "rb") as fh:
        d = fh.read(8192)
        nul = b"\x00" in d or b"\x00" in fh.read()
except Exception:
    sys.exit(2)
if not d:
    sys.exit(1)
nonprint = sum(b == 0 or b < 9 or 13 < b < 32 or b > 126 for b in d)
sys.exit(0 if (nul or nonprint > len(d) * 0.30) else 1)
PY
}

# --- 1. Inventory: every file with perms, flagging executables, (unreviewable) binaries,
# symlinks (nothing below follows them) and files that couldn't be read.
hdr "1. Files  [exec = gets run; BINARY = can't be reviewed by eye; LINK = not followed, review its target; UNREAD = couldn't be read. All but exec are HIGH]"
n_files=0
while IFS= read -r -d '' f; do
  n_files=$((n_files + 1))
  mark="-"
  [ -x "$f" ] && mark="exec"
  if [ -L "$f" ]; then
    mark="LINK"; high=1                   # its target isn't part of this review -> HIGH
  else
    is_binary "$f"
    case $? in
      0) mark="BINARY"; high=1 ;;         # non-text: unreviewable -> HIGH
      1) ;;
      *) mark="UNREAD"; high=1 ;;         # not reviewed at all -> HIGH
    esac
  fi
  printf '  %-7s %s\n' "[$mark]" "$(ls -ldh -- "$f" 2>/dev/null)"
done < <(find "$target" \( -type f -o -type l \) -print0)
[ "$n_files" -eq 0 ] && echo "  (no files)"

# --- 2. Dynamic shell execution: runs at LOAD time, before the model sees output.
hdr "2. Dynamic shell execution  [HIGH]"
scan -E '!`[^`]+`|^```!' && high=1

# --- 3. Tool pre-approvals (allowed-tools: suppresses per-call prompts while active;
# plugin.json commands can carry the same grant as allowedTools).
hdr "3. Tool pre-approvals (allowed-tools: / allowedTools)"
scan -iE '^allowed-tools:|"allowedTools"[[:space:]]*:'

# --- 4. Skills, commands and agents. Decided by what a file IS, not where it sits: a
# SKILL.md is a skill wherever it was copied, and the reference .md files beside it are
# not. Every one is listed, so a frontmatter trick can mislabel a file but not hide it.
hdr "4. Skills/commands/agents  [MODEL-INVOCABLE = Claude can start it on its own]"
# Print $1's YAML frontmatter the way Claude Code reads it: a leading BOM dropped, then
# after an opening `---` line, up to the next `---`, even mid-line. With no closing `---`
# there is no frontmatter.
frontmatter() {
  LC_ALL=C awk -v bom="$(printf '\357\273\277')" '
       NR == 1 { if (index($0, bom) == 1) $0 = substr($0, 4)
                 if ($0 !~ /^---[[:space:]]*$/) exit; next }
       (i = index($0, "---")) { buf = buf substr($0, 1, i - 1) "\n"; closed = 1; exit }
       { buf = buf $0 "\n" }
       END { if (closed) printf "%s", buf }' "$1" 2>/dev/null
}
# From frontmatter on stdin, print top-level key $1 (quoted or not) and the lines under it.
fm_key() {
  awk -v k="$1" '/^[^[:space:]#-]/ { on = $0 ~ ("^[\"\047]?" k "[\"\047]?[[:space:]]*:") } on'
}
# Opted out = exactly one disable-model-invocation key, set to true on its own line.
# Anything else (missing, duplicated, quoted, nested) counts as model-invocable. Without a
# YAML parser a multi-line string can still fake the line; the file stays listed.
opted_out() {
  local v; v=$(fm_key disable-model-invocation)
  case $v in *$'\n'*) return 1 ;; esac
  printf '%s\n' "$v" | grep -qE '^disable-model-invocation[[:space:]]*:[[:space:]]*(true|True|TRUE)[[:space:]]*(#.*)?$'
}
# True if frontmatter on stdin opens a quoted value (a quote after a space, `:`, `,`, `[`
# or `{`) that isn't closed on the same line. YAML may carry it onto the next lines,
# swallowing what looks like keys.
open_quote() {
  awk '{ s = $0
         while (match(s, /(^|[[:space:][{,:])["\047]/)) {
           s = substr(s, RSTART + RLENGTH - 1); q = substr(s, 1, 1); s = substr(s, 2)
           if (q == "\"") gsub(/\\./, "", s); else gsub("\047\047", "", s)
           if (!(i = index(s, q))) { open = 1; break }
           s = substr(s, i + 1)
         } }
       END { exit !open }'
}
# Frontmatter keys that run commands, start servers or change permissions while active.
live_keys='hooks mcpServers lspServers monitors settings permissionMode'
found=0
while IFS= read -r -d '' f; do
  found=1
  fm=$(frontmatter "$f")
  tools=""
  case "$f" in
    */agents/*|agents/*)
      # Claude delegates to an agent by its description and no frontmatter turns that
      # off (deny `Agent(<name>)` does). Without a tools: line it inherits every tool.
      tools=$(fm_key tools <<<"$fm")
      case $tools in
        "") tag="agent; no tools: line -> inherits ALL tools" ;;
        *$'\n'*) tag="agent; tools: listed below" ;;
        *) tag="agent; $tools"; tools="" ;;
      esac ;;
    *)
      if ! opted_out <<<"$fm"; then tag="MODEL-INVOCABLE"
      elif open_quote <<<"$fm"; then tag="opt-out unverified: a quoted value spans lines -> treat as MODEL-INVOCABLE"
      else tag="opted out of model invocation"; fi ;;
  esac
  echo "  $f  [$tag]"
  # Print those keys (and a multi-line tools list) as written, under a `|`. If one is
  # there in a layout fm_key can't read (an indented or flow-style root), print it all.
  shown=$({ [ -n "$tools" ] && printf '%s\n' "$tools"
            for k in $live_keys; do fm_key "$k" <<<"$fm"; done; })
  [ -z "$shown" ] && grep -qE "(^|[[:space:]{,])[\"']?(${live_keys// /|})[\"']?[[:space:]]*:" <<<"$fm" && shown=$fm
  [ -n "$shown" ] && printf '%s\n' "$shown" | sed 's/^/      | /'
done < <(find "$target" -type f \( -iname 'SKILL.md' -o -path '*/commands/*.md' -o -path 'commands/*.md' \
  -o -path '*/agents/*.md' -o -path 'agents/*.md' \) -print0)
[ "$found" -eq 0 ] && echo "  none"

# --- 5. Commands Claude Code runs without a per-use prompt: settings hooks, statusLine
# and helper keys, and env vars that make child processes run code; plugin hooks
# (hooks/hooks.json, or inline/by path in plugin.json); MCP and LSP servers; monitors.
# Plus the grants that skip prompts (permissions.allow, defaultMode, allowedTools).
# Found by key, not by schema, so an odd shape can't hide a command. A `.claude-plugin/`
# dir is flagged: enabling it activates them all. (Frontmatter hooks are listed in §4.)
hdr "5. Auto-run commands and grants (hooks, permissions, plugin manifests, MCP/LSP servers, monitors)"
python3 - "$target" <<'PY' || { echo "  ERROR: section 5 is INCOMPLETE (see above)"; high=1; }
import json, os, re, sys

sys.stdout.reconfigure(errors="backslashreplace")   # a lone "\ud800" in a value can't crash print
target = sys.argv[1]
NAMES = re.compile(r'^(settings.*|hooks|plugin|marketplace|\.mcp|\.lsp|monitors)\.json(\.example)?$')
# settings / MCP keys whose string value is itself a command
HELPERS = {"apiKeyHelper", "awsAuthRefresh", "awsCredentialExport", "gcpAuthRefresh",
           "otelHeadersHelper", "processWrapper", "headersHelper", "fileSuggestion",
           "subagentStatusLine"}
# keys that grant permissions or approve tools/servers without a prompt
GRANTS = {"allow": "pre-approves", "allowedTools": "pre-approves", "defaultMode": "permission mode",
          "additionalDirectories": "widens file access", "enableAllProjectMcpServers": "auto-approves MCP",
          "enabledMcpjsonServers": "auto-approves MCP"}
# `env` vars that make the shells and tools Claude Code starts load or run other code
# (HOME, ZDOTDIR and XDG_CONFIG_HOME move the rc/config files zsh and git read)
EXEC_ENV = re.compile(r'^(BASH_ENV|ENV|ZDOTDIR|HOME|XDG_CONFIG_HOME|SHELLOPTS|PS4|PATH|NODE_OPTIONS|NODE_PATH|BUN_OPTIONS|'
                      r'PYTHON\w*|PERL5\w*|RUBYOPT|JAVA_TOOL_OPTIONS|_JAVA_OPTIONS|'
                      r'CLAUDE_CODE_SHELL_PREFIX|CLAUDE_CODE_PROCESS_WRAPPER|CLAUDE_ENV_FILE|'
                      r'(LD|DYLD|GIT|BASH_FUNC)_\w*)$')
# plugin.json keys that may point at another file (relative to the plugin root)
COMPONENTS = ("hooks", "mcpServers", "lspServers", "monitors")
# plugin.json keys that point at markdown outside the default dirs §4 looks in
LOCATIONS = ("commands", "agents", "skills", "outputStyles")

def commands(node, path=""):
    if isinstance(node, dict):
        cmd = node.get("command")
        if isinstance(cmd, (str, list)):
            args = node.get("args")
            parts = (cmd if isinstance(cmd, list) else [cmd]) + (args if isinstance(args, list) else [])
            yield path or ".", " ".join(map(str, parts))
        elif isinstance(node.get("type"), str) and ("url" in node or "prompt" in node):
            yield path or ".", f"[{node['type']}] {str(node.get('url') or node.get('prompt'))[:120]}"
        elif isinstance(node.get("type"), str) and "tool" in node:   # an mcp_tool hook
            yield path or ".", f"[{node['type']}] {node.get('server')}/{node['tool']} {json.dumps(node.get('input'))[:120]}"
        for k, v in node.items():
            sub = f"{path}.{k}" if path else k
            if k in HELPERS and isinstance(v, str):
                yield sub, v
            if k == "env" and isinstance(v, dict):
                yield from ((f"{sub}.{n}", str(x)) for n, x in v.items() if EXEC_ENV.match(str(n)))
            if k in GRANTS and (k != "allow" or path.endswith("permissions")):
                yield sub, f"[{GRANTS[k]}] {json.dumps(v)[:200]}"
            yield from commands(v, sub)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from commands(v, f"{path}[{i}]")

if os.path.isfile(target):
    # A lone SKILL.md isn't config JSON; only parse what could be.
    is_json = NAMES.match(os.path.basename(target)) or target.endswith(".json")
    files, plugin_dirs = ([target] if is_json else []), []
else:
    files, plugin_dirs = [], []
    for d, dirs, names in os.walk(target):
        if os.path.basename(d) == ".claude-plugin":
            plugin_dirs.append(d)
        files += [os.path.join(d, n) for n in names if NAMES.match(n)]

for pd in sorted(plugin_dirs):
    root = os.path.dirname(pd)
    note = "; its bin/ joins the Bash PATH" if os.path.isdir(os.path.join(root, "bin")) else ""
    print(f"  PLUGIN {root}: enabling it activates everything it declares{note}")

failed = False
seen, queue = set(), sorted(files)
while queue:
    p = os.path.normpath(queue.pop(0))
    if p in seen:
        continue
    seen.add(p)
    try:
        d = json.load(open(p))
    except Exception as e:   # Claude Code's parser may still accept it (huge numbers, deep nesting)
        print(f"  ERROR {p}: can't parse as JSON ({e}) -> review it by hand"); failed = True; continue
    try:
        found = list(commands(d))
        if os.path.basename(p) == "plugin.json" and isinstance(d, dict):
            root = os.path.dirname(os.path.dirname(p))
            exp = d.get("experimental")
            refs = [(k, d.get(k)) for k in COMPONENTS + LOCATIONS]
            refs.append(("experimental.monitors", exp.get("monitors") if isinstance(exp, dict) else None))
            for key, val in refs:
                if key in LOCATIONS and isinstance(val, dict):
                    # {name: {source | content, allowedTools}}; the walk above reports allowedTools
                    for name, spec in val.items():
                        src = spec.get("source") if isinstance(spec, dict) else None
                        body = spec.get("content") if isinstance(spec, dict) else spec
                        found.append((f"{key}.{name}", f"points to {src}" if isinstance(src, str)
                                      else f"inline: {str(body)[:120]}"))
                    continue
                for ref in ([val] if isinstance(val, str) else val if isinstance(val, list) else []):
                    if not isinstance(ref, str):
                        continue
                    found.append((key, f"points to {ref}"))
                    # Claude Code only loads component paths inside the plugin root; follow
                    # the JSON ones there.
                    f = os.path.normpath(os.path.join(root, ref))
                    inside = os.path.commonpath([os.path.abspath(root), os.path.abspath(f)]) == os.path.abspath(root)
                    if inside and os.path.isfile(f) and key not in LOCATIONS:
                        queue.append(f)
        for where, cmd in found:
            print(f"  {p}: {where} -> {cmd}")
        if not found:
            print(f"  ({p}: no commands)")
    except Exception as e:   # e.g. nesting deep enough to exhaust the stack
        print(f"  ERROR {p}: {e!r} -> not fully read, review it by hand"); failed = True
if not seen and not plugin_dirs:
    print("  none")
sys.exit(3 if failed else 0)
PY

# --- 6. Sensitive tokens: network egress, secret access, code-gen, and package runners
# that download and run unpinned code. Scans ALL files. Tool names must stand alone as
# words (so `ncat` doesn't hit "truncate"); paths, URLs and key names match anywhere.
hdr "6. Sensitive tokens  [HIGH]"
words='curl|wget|nc|netcat|ncat|telnet|base64|npx|bunx|pnpx|uvx|pipx[[:space:]]+run|npm[[:space:]]+(exec|x)|bun[[:space:]]+x|pnpm[[:space:]]+dlx|yarn[[:space:]]+dlx|uv[[:space:]]+tool[[:space:]]+run'
anywhere='/dev/tcp|https?://|/\.ssh|/\.aws|id_rsa|id_ed25519|credentials|/\.env|secrets/|_API_KEY'
danger="(^|[^[:alnum:]])($words)([^[:alnum:]]|$)|$anywhere"
scan -E "$danger" && high=1

echo
echo "Reviewed $n_files file(s) under '$target'."
echo "Reminder: this reports; YOU decide. See docs/skill-security.md."
if [ "$strict" -eq 1 ] && [ "$high" -eq 1 ]; then
  echo "STRICT: high-signal findings present -> exit 1"; exit 1
fi
exit 0
