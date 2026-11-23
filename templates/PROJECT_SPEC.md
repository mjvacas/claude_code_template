# PROJECT_SPEC template. Copy to docs/PROJECT_SPEC.md, customize, delete this header.
# Optional, scale to project size. Pair with ARCHITECTURE.md (how) and BUILD_PLAN.md (order).
# ---

# <Project>: Spec

> The "why" and "what". This is the source of truth for scope. Read it at session start
> and don't relitigate what's settled here (revisit via a new ADR).

## Mission

One paragraph: what this is and the single outcome it exists to produce.

## Scope

- **In scope (v1):** …
- **Explicitly NOT in scope:** … (what you are deliberately not doing. That matters as
  much as what you are doing, because it stops scope creep.)

## Success metrics

How you'll know it's working. Prefer measurable.

## Hard constraints

The nonnegotiable invariants (mirror the ones in CLAUDE.md that are guarded by code).

## Operating principles

The handful of rules that resolve future judgment calls when the spec is silent.
