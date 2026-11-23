# ADR-006: Versioning and release management (beta SemVer and vendoring pins based on tags)

## Status

Accepted (2026-06-13)

Supersedes the standing "this template isn't versioned" decision recorded in
`CHANGELOG.md` (date stamped entries, validated against `cookiecutter-django`).
That decision was never an ADR. This record retires it.

## Context

Until now the template was deliberately **unversioned**. `CHANGELOG.md` carried
date stamped sections, on the reasoning (validated against `cookiecutter-django`
and similar projects) that template consumers generate once and date stamps
suffice.

That reasoning does not hold for *this* template. Projects in the `cookiecutter`
style are **generated once and then diverge**. There is no upgrade relationship,
so a version number buys little. This template instead ships an explicit
**re-sync contract**. Adopters vendor files and record an upstream pin in
`VENDORED.md` ([ADR-001](./ADR-001-vendor-with-source-pin.md)), then periodically
re-sync (see `docs/ADOPTING.md` § Re-syncing). Today that pin is a raw commit SHA
(`fb38535`, `545e954`, …). A SHA cannot answer the three questions an adopter
actually asks at re-sync time:

1. **Am I behind?**
2. **By how much?**
3. **Is the update *breaking*? Will it require me to act?**

Going public is the trigger to fix this. A public template needs a concrete
stability marker and a legible story about how stable it is and how to upgrade.
But the project has **not yet accumulated meaningful external adoption
feedback**, so claiming a stable 1.0 contract would be dishonest. The honest
status is **beta**.

## Decision

Adopt **Semantic Versioning**, with MAJOR, MINOR, and PATCH defined against the
template's *adoption contract* (what an adopter vendors and depends on):

- **MAJOR.** A **breaking** change to the adoption contract, for example: a
  vendored file removed, renamed, or relocated, a convention changed so re-sync
  requires the adopter to act, or a skill, command, or hook an adopter may
  depend on removed.
- **MINOR.** A **backward compatible addition**: a new skill, command, hook, or
  doc, or a new optional capability that needs no adopter action.
- **PATCH.** Fixes, doc tweaks, and internal cleanups that need no adopter action.

**Start in beta at `v0.1.0`.** Per SemVer's 0.x convention the public adoption
contract is *not yet guaranteed stable*. Until 1.0, breaking changes bump MINOR
(`0.x` → `0.(x+1)`). Adopters should read the `CHANGELOG` on **every** re-sync
rather than trusting that a bump below MAJOR is safe. History prior to `v0.1.0`
stays in the original date stamped `CHANGELOG` sections as the record from
before versioning.

**Cut `v1.0.0` on a criterion, with no target date:** when external adoption
feedback has validated the adoption contract as stable enough to commit to
breaking changes only in MAJOR releases.

**Mechanism:**

- Releases are **annotated git tags** (`v0.1.0`) plus **GitHub Releases**.
- Release notes are generated from the `CHANGELOG`'s version section. On release,
  rename `[Unreleased]` → `[x.y.z] - <date>` and open a fresh `[Unreleased]`.
- Adopters pin `VENDORED.md` to a **release tag**. The commit SHA remains the
  exact anchor (for files vendored between releases). Re-sync becomes: *bump to
  the newest tag, read the `CHANGELOG` between your tag and it, treat a MAJOR
  (or, in 0.x, MINOR) bump as "expect to act."*

## Consequences

- Adopters gain a legible upgrade path. A tag plus SemVer answers "behind?",
  "how much?", and "breaking?". A bare SHA could answer none of them.
- Beta (0.x) sets honest expectations that the contract may still shift and
  avoids the overpromise of a premature 1.0.
- Cost: every release now carries discipline. Classify the change (PATCH,
  MINOR, or MAJOR), perform the `[Unreleased]` → `[x.y.z]` rename, cut the tag,
  and publish a GitHub Release. This replaces the lighter date stamp ritual.
- The date stamped `CHANGELOG` convention is retired going forward. The existing
  date sections remain as the historical record from before 0.1.0.
- `docs/ADOPTING.md` and the `VENDORED.md` schema change to recommend tag pins.
  Existing adopters pinned to a SHA keep working (a tag *is* a SHA) and move to
  tag pins on their next re-sync.

## Alternatives Considered

- **Keep unversioned and date stamped (the prior decision).** Rejected: it's
  opaque to adopters who have a re-sync contract and provides no stability
  marker. The `cookiecutter-django` analogy that justified it doesn't hold
  (generate once vs. re-sync).
- **Start at `v1.0.0` now.** Rejected: with little external feedback it would
  overpromise contract stability and force a MAJOR bump for any early change
  that shapes the contract. Beta `0.x` is the honest signal.
- **Date based versioning (CalVer, e.g. `2026.06`).** Considered: legible "how
  old," but it doesn't encode whether a change is *breaking*, which is the
  adopter's real re-sync question. SemVer encodes upgrade risk directly.
- **Tag releases but keep vendoring pins as SHAs only.** Rejected as a half
  measure. The legibility win comes precisely from adopters pinning to tags.
  Pins that are only SHAs stay opaque.
