# ARCHITECTURE template — copy to docs/ARCHITECTURE.md, customize, delete this header.
# Optional; scale to project size. The "how"; pairs with docs/adr/ for the *why*.
# ---

# <Project> — Architecture

> Tech decisions, layout, and the key abstractions. Each significant decision has a
> one-line highlight below and a full record in `docs/adr/`.

## Tech stack

Chosen tools + a one-line reason each. Include a **Deliberately NOT used (yet)**
list — naming what you're avoiding, and why, prevents speculative complexity.

## Repository layout

A tree with a one-line purpose per directory. Note which modules are SHARED (used
by more than one context — e.g. prod + tests/simulation) so they don't get forked.

## Core data types

The dataclasses / types other modules depend on — define these first (types-first).

## Key abstractions

The interfaces / seams that let pieces swap: one line each — what it is + why it exists.

## Decisions

One-line highlight per ADR (full records in `docs/adr/`).
