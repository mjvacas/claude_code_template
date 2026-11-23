# ARCHITECTURE template. Copy to docs/ARCHITECTURE.md, customize, delete this header.
# Optional, scale to project size. The "how". Pairs with docs/adr/ for the *why*.
# ---

# <Project>: Architecture

> Tech decisions, layout, and the key abstractions. Each significant decision has a
> one line highlight below and a full record in `docs/adr/`.

## Tech stack

Chosen tools and a one line reason for each. Include a **Deliberately NOT used (yet)**
list. Naming what you're avoiding, and why, prevents speculative complexity.

## Repository layout

A tree with a one line purpose per directory. Note which modules are SHARED (used
by more than one context, e.g. prod and tests or simulation) so they don't get forked.

## Core data types

The dataclasses or types other modules depend on. Define these first (types first).

## Key abstractions

The interfaces or seams that let pieces swap. One line each: what it is and why it exists.

## Decisions

One line highlight per ADR (full records in `docs/adr/`).
