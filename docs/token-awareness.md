# Token Awareness

Higher-consumption models (Fable, the larger Opus tiers) make token cost a
first-class concern — for you running sessions and for adopters weighing what
this template costs them. This doc makes already-known costs **legible at the
moment you decide**: adopting a plugin, wiring a feature, choosing a model.

Two different things get called "token awareness"; this doc is the first:

- **Legibility** *(this doc)* — surface the costs you can already see or
  estimate, at the decision point. Ships now, ~zero recurring cost.
- **Measurement** — get *real* per-task numbers by running a benchmark. That's
  `cc-task-bench` (see [ADR-003](adr/ADR-003-cc-task-bench-scope.md)); its V1
  methodology ships, the runner is V2. Heavy, costs real dollars per run.

The guiding rule here: **a stale cost number is worse than none.** So this doc
prefers durable *cost classes* over frozen token/$ figures, and points you at
Claude Code's live native tools (`/context`, `/usage`) for the actual numbers.

## Cost classes

Most cost decisions don't hinge on "47 tokens" — they hinge on the *shape* of
the cost: paid once, or every session, or every turn? These four classes are
the vocabulary the rest of the repo annotates against. They map onto the plugin
catalog's two cost axes (`tokens.<model>.always_on` / `tokens.<model>.on_invoke`,
surfaced during [plugin discovery](ADOPTING.md#plugin-discovery)) so the doc and
the catalog speak one language.

| Class | Tag | What it means | Catalog axis | Examples in this repo |
|-------|-----|---------------|--------------|-----------------------|
| Free / local | `free-local` | Runs as code; emits ~nothing into the *model's* context (terminal-only output counts — it never enters the window) | — | `block-dangerous.sh`, `precompact-snapshot.sh`, `statusline.sh`, the `scripts/` |
| One-shot on use | `on-use` | Loaded into context only when invoked; paid once per invocation | `tokens.*.on_invoke` | skills (`verify-refactor`, `llm-eval`, …), `/handoff`, `/adr`, `/commit` |
| Always-on / session | `session` | Loaded at session start, resident the whole session — the "context tax" | `tokens.*.always_on` | `CLAUDE.md`, `@AI_CONTEXT.md`, the `session-context.sh` injection, a plugin's `always_on` |
| Per-prompt recurring | `per-prompt` | Re-injected on **every** user turn; scales with conversation length | (not modeled by the catalog — flag it) | `clock.sh` heartbeat |

The `session` vs. `per-prompt` split is the load-bearing one: it's exactly the
distinction [`CONTRIBUTING.md`](../CONTRIBUTING.md)'s opt-in principle draws
("always-on **or per-prompt** context cost ships unwired").

## What this template costs you (the ledger)

Adopting the full template adds a fixed `session` tax — context loaded before
any work happens. The itemization is durable; the numbers are not, so read the
numbers live.

**What's in the always-on tax** (`session` class, every one):

| Item | How to see its real cost |
|------|--------------------------|
| `CLAUDE.md` | `/context` → "Memory files" |
| `@AI_CONTEXT.md` (auto-imported by `CLAUDE.md`) | `/context`; capped at 750 lines by design — see [ADR-004](adr/ADR-004-ai-context-archive-threshold-bump.md) |
| `MEMORY.md` index + recalled auto-memories | `/context` (varies by what's recalled) |
| `session-context.sh` SessionStart injection | `/context` → conversation/system |
| Each baseline/discovered plugin's `always_on` | the plugin's catalog entry; `/usage` for the live split |

**Don't trust a frozen total — measure it:**

- **`/context`** shows the live context-window composition by component (memory
  files, tools, MCP, messages, free space) and flags what's heavy — the
  authoritative answer to "what's my session tax right now."
- **`/usage`** (and the related `/cost` / `/stats`) reports the session's
  estimated cost and, depending on your plan, can break it down per component
  (skill / subagent / plugin / MCP) — the direct answer to "how much is this
  plugin costing me."

> Slash-command names and the exact breakdown evolve between Claude Code
> releases — confirm them against your version (run the command, or check the
> current docs) rather than trusting this list verbatim. Same caveat
> [`skill-security.md`](skill-security.md) applies to setting keys.

The single largest fixed item is usually a full `AI_CONTEXT.md`; its budget is
owned by [ADR-004](adr/ADR-004-ai-context-archive-threshold-bump.md) — don't copy
the figure here, it would drift. Run `/context` for your actual total rather than
trusting any number in prose.

## Which model for which task

A routing default, not a measured result. Route by **correctness-risk and
reasoning depth**, not by habit — the question high-consumption models like
Fable sharpen (they earn their cost on open-ended reasoning and waste it on
bounded, verifiable work) is the same question Opus poses, just louder.

| Task shape | Tier | Why |
|------------|------|-----|
| Ambiguous spec, architecture, subtle refactor where an error is expensive *and* hard to detect | High-capability (e.g. Opus 4.8, Fable) | One wrong-but-plausible answer costs more than the model |
| Bounded, well-specified change with a clear correctness check | Mid (e.g. Sonnet 4.6) | A cheaper model + a verification loop beats an expensive one-shot |
| Mechanical / verifiable: test scaffolding from a repro, code search, rote edits | Floor (e.g. Haiku 4.5) | Output is cheap to check; pay the floor |

The tiers are the spine; the model IDs are today's examples and will age. This
table is a **heuristic to be superseded by `cc-task-bench` V2 measured data**
across its task families (refactor / explore / test-write) — see
[ADR-003](adr/ADR-003-cc-task-bench-scope.md) and
[ADR-005](adr/ADR-005-token-awareness-legibility.md).

## Before you add a recurring cost

Anything you add in the `session` or `per-prompt` class is a tax every adopter
pays forever. The repo's standing rule — [`CONTRIBUTING.md`](../CONTRIBUTING.md)
§ "Recurring-token-cost features default to opt-in" — is that such features ship
**unwired**, with a documented enable snippet. The `clock.sh` heartbeat
(`per-prompt`, ships unwired — see
[`docs/claude-code-setup.md`](claude-code-setup.md#optional-session-clock-heartbeat))
is the worked example. When vetting a third-party skill or plugin, treat its
cost class as a [vetting dimension](skill-security.md#vetting-checklist-before-adding-anything-from-online).
