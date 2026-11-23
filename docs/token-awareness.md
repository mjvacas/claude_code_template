# Token Awareness

Models that consume more tokens (Fable, the larger Opus tiers) make token cost a
first class concern, both for you running sessions and for adopters weighing
what this template costs them. This doc makes costs you already know **legible
at the moment you decide**: adopting a plugin, wiring a feature, choosing a model.

Two different things get called "token awareness". This doc is the first:

- **Legibility** *(this doc)*. Surface the costs you can already see or
  estimate, at the decision point. Ships now, ~zero recurring cost.
- **Measurement.** Get *real* per task numbers by running a benchmark. That's
  `cc-task-bench` (see [ADR-003](adr/ADR-003-cc-task-bench-scope.md)). Its V1
  methodology ships, the runner is V2. Heavy, costs real dollars per run.

The guiding rule here is that **a stale cost number is worse than none.** So this
doc prefers durable *cost classes* over frozen token and dollar figures and points
you at Claude Code's live native tools (`/context`, `/usage`) for the actual numbers.

## Cost classes

Most cost decisions turn on the *shape* of the cost rather than an exact figure
like "47 tokens". Is it paid once, or every session, or every turn? These four
classes are the vocabulary the rest of the repo annotates against. They map onto
the two cost axes Claude Code's plugin catalog has used (`always_on` and
`on_invoke`). A plugin's actual cost shows in `/context` once it's installed (see
[plugin discovery](ADOPTING.md#plugin-discovery)).

| Class | Tag | What it means | Catalog axis | Examples in this repo |
|-------|-----|---------------|--------------|-----------------------|
| Free, local | `free-local` | Runs as code and emits ~nothing into the *model's* context (output that only shows in the terminal still qualifies, because it never enters the window) | none | `block-dangerous.sh`, `statusline.sh`, the `scripts/` |
| One shot on use | `on-use` | Loaded into context only when invoked. Paid once per invocation | `tokens.*.on_invoke` | skills (`verify-refactor`, `llm-eval`, …), `/handoff`, `/adr`, `/commit` |
| Always on (session) | `session` | Loaded at session start and resident the whole session (the "context tax") | `tokens.*.always_on` | `CLAUDE.md`, `@AI_CONTEXT.md`, the `session-context.sh` injection, a plugin's `always_on` |
| Per prompt, recurring | `per-prompt` | Reinjected on **every** user turn. Scales with conversation length | (not modeled by the catalog, so flag it) | `clock.sh` heartbeat |

The `session` vs. `per-prompt` split matters most. It's exactly the distinction
[`CONTRIBUTING.md`](../CONTRIBUTING.md)'s opt-in principle draws
("always on **or per-prompt** context cost ships unwired").

## What this template costs you (the ledger)

Adopting the full template adds a fixed `session` tax, the context loaded before
any work happens. The itemization is durable. The numbers aren't, so read them
live.

**What's in the always on tax** (`session` class, every one):

| Item | How to see its real cost |
|------|--------------------------|
| `CLAUDE.md` | `/context` → "Memory files" |
| `@AI_CONTEXT.md` (imported automatically by `CLAUDE.md`) | `/context`. Capped at 1000 lines by design (see [ADR-007](adr/ADR-007-ai-context-archive-threshold-1000.md)) |
| `MEMORY.md` index and recalled auto memories | `/context` (varies by what's recalled) |
| `session-context.sh` SessionStart injection | `/context` → conversation or system |
| Each baseline or discovered plugin's `always_on` | `/context` once it's installed, `/usage` for the live split |

**Don't trust a frozen total. Measure it:**

- **`/context`** shows what fills the live context window, by component (memory
  files, tools, MCP, messages, free space), and flags what's heavy. It's the
  authoritative answer to "what's my session tax right now."
- **`/usage`** (and the related `/cost` and `/stats`) reports the session's
  estimated cost and, depending on your plan, can break it down per component
  (skill, subagent, plugin, MCP). It's the direct answer to "how much is this
  plugin costing me."

> Slash command names and the exact breakdown evolve between Claude Code
> releases. Confirm them against your version (run the command, or check the
> current docs) rather than trusting this list verbatim.
> [`skill-security.md`](skill-security.md) makes the same caveat about setting keys.

For a view that's always on, the bundled `.claude/statusline.sh` renders the live
session context as absolute tokens against the window (`ctx 152k/1M`, with a `⚠`
nudge at ~200k regardless of window size). It also shows the signal that reflects
your *actual* constraint. On pay as you go plans that's an estimated session cost
(`~$`, computed at API list prices). On subscription plans it's 5 hour and weekly
rate limit usage, each with its reset clock (`5h 24% (16:30)` and
`7d 41% (Tue 16:30)`). On those plans the dollar figure is notional (a subscription is a
flat fee, with no per token billing), so it's hidden to avoid reading as a charge
(the rate limit windows carry the real signal there). Context and budget are two
different meters (see [Session context vs. budget](#session-context-vs-budget)
below). It's a `free-local` signal. The status line never enters the model's
context, so this costs zero tokens.

The single largest fixed item is usually a full `AI_CONTEXT.md`. Its budget is
owned by [ADR-007](adr/ADR-007-ai-context-archive-threshold-1000.md). Don't copy
the figure here, it would drift. Run `/context` for your actual total rather than
trusting any number in prose.

## Session context vs. budget

The status line shows two meters that are easy to conflate but behave
oppositely:

- **Session context** (`ctx 152k/1M`): how full the current window is. It is
  **resettable**. `/clear` or `/handoff` starts a fresh window and the count
  drops back toward zero.
- **Rate limit budget** (`5h 24% (16:30)` and `7d 41% (Tue 16:30)`): how much of
  your 5 hour and weekly (`seven_day`) allowance you have burned, each with the
  wall clock time it resets. It is **cumulative**. It keeps climbing across sessions.
  A context reset does **not** refund it.

Two consequences worth holding onto:

- **The `~200k` nudge is about quality. It isn't about billing.** Long context
  attention degrades well before a 1M window is "full", so the line flags ~200k
  regardless of window size. A raw fill % would not trip 80% until 800k on a 1M
  model. Read the nudge as "this conversation is getting long," independent of
  budget.
- **Clearing context cuts *future* burn. It doesn't undo *past* spend.** Every
  turn resends the whole window, so a bloated context quietly inflates weekly
  (`7d`) burn for the rest of the session. Ending at a natural boundary with
  `/handoff` (it records state, then you start clean) shrinks the window and slows
  that bleed. The `5h` and `7d` meters still keep whatever they already showed.
  What you buy is a cheaper *future*. There's no refund.

So watch `ctx` to decide when to **hand off and clear** (long conversation at a
natural stopping point). Watch `5h` and `7d` to decide when to **slow down or
route cheaper** (next section). They are different signals. Clearing context
doesn't fix a depleted budget. A fresh context doesn't restore budget.

## Compaction

Compaction replaces the conversation so far with a summary written by the model.
It saves tokens on every later turn, but the session then works from the summary.
Exact instructions and the reasons behind decisions can drop out. It happens three
ways:

- **Manual.** You run `/compact` (optionally with instructions for the summary).
- **Automatic.** Near the context limit, so the session can continue.
- **Idle.** A long conversation left alone for about 54 minutes is compacted just
  before its one hour prompt cache expires, so your next message doesn't reread the
  whole context uncached. By default it applies from 200K tokens, which on a 1M window
  is only a fifth full. It needs an interactive terminal session on the one hour cache.
  Anthropic turns it on server side. Nothing in your config changes when it does.

Idle compaction trades context for cost. If you keep long sessions open and the context
is the valuable part, turn it off with `"idleCompaction": false` in your **user**
settings (`~/.claude/settings.json`, or `/config` → Idle compaction), or raise its
threshold with the `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` environment variable (minimum
100000). The setting needs Claude Code 2.1.290 or later. A session started on an older
version ignores it until restarted. In that session only `"autoCompactEnabled": false`
stops it, which turns off automatic compaction too. The template doesn't set it because
the tradeoff is personal. A project setting would override every collaborator's choice.

Nothing is deleted. Claude Code keeps the full transcript in `~/.claude/projects/` (30
days by default, `cleanupPeriodDays`). Its compaction summary tells the session where
to find it. To see which of your sessions were compacted and why, run
`scripts/compaction-report.sh` from your template clone. It lists each compaction with
its size and how long the session had been idle. It never prints message text. Before
2.1.290, idle compactions were recorded with trigger "manual", so check the idle
column, not the trigger. For example (illustrative data):

```text
time              project                   trigger     tokens  idle min  version    flag
2026-10-14 16:57  my-app                    manual     312,480      53.9  2.1.289    idle (notice)
2026-10-15 09:11  my-app                    auto       968,211       0.1  2.1.302
2026-10-15 12:36  api-server                manual     205,377      54.5  2.1.280    likely idle (gap)
2026-10-16 15:16  my-app                    auto       241,090      53.8  2.1.302    idle (notice)

4 compaction(s); 3 idle (2 by notice, 1 by gap)
```

Only the 968K row hit the context limit. The other three came about 54 minutes after the
last message, at 205K to 312K tokens, a fifth to a third of a 1M window. "idle (notice)"
means Claude Code recorded its own "Compacted while idle" notice. "likely idle (gap)" is
inferred from the 50 to 60 minute gap, for versions that didn't record one.

## Which model for which task

This is a routing default. It isn't a measured result. Route by **correctness risk
and reasoning depth** instead of by habit. High consumption models like Fable
make the routing question sharper (they earn their cost on open ended reasoning and
waste it on bounded, verifiable work), but it's the same question Opus poses, just louder.

| Task shape | Tier | Why |
|------------|------|-----|
| Ambiguous spec, architecture, subtle refactor where an error is expensive *and* hard to detect | High capability (e.g. Opus 5.5, Fable 5.1) | One answer that's wrong but plausible costs more than the model |
| Bounded, well specified change with a clear correctness check | Mid (e.g. Sonnet 5.5) | A cheaper model plus a verification loop beats a single pass from an expensive one |
| Mechanical and verifiable: test scaffolding from a repro, code search, rote edits | Floor (e.g. Haiku 5.5) | Output is cheap to check, so pay the floor |

The tiers are the spine. The model IDs are today's examples and will age. This
table is a **heuristic to be superseded by `cc-task-bench` V2 measured data**
across its task families (refactor, explore, test-write). See
[ADR-003](adr/ADR-003-cc-task-bench-scope.md) and
[ADR-005](adr/ADR-005-token-awareness-legibility.md).

## Before you add a recurring cost

Anything you add in the `session` or `per-prompt` class is a tax every adopter
pays forever. The repo's standing rule ([`CONTRIBUTING.md`](../CONTRIBUTING.md)
§ "Features with a recurring token cost default to opt-in") is that such features
ship **unwired**, with a documented enable snippet. The `clock.sh` heartbeat
(`per-prompt`, ships unwired, see
[`docs/claude-code-setup.md`](claude-code-setup.md#optional-session-clock-heartbeat))
is the worked example. When vetting a third party skill or plugin, treat its
cost class as a [vetting dimension](skill-security.md#vetting-checklist-before-adding-anything-from-online).
