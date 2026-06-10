---
description: Scaffold a new Architecture Decision Record from the template, numbered to the next slot.
argument-hint: "<short decision title>"
allowed-tools: Bash(ls:*), Bash(git log:*), Bash(date:*), Read, Write
---

Record a significant or hard-to-reverse decision as an ADR.

## Existing ADRs

- !`ls docs/adr/ 2>/dev/null | grep -E '^ADR-' || echo "(none yet)"`
- Today's date: !`date '+%Y-%m-%d'` — use this for the Status date; dates remembered from context go stale

## Your task

1. Determine the next number: highest existing `ADR-NNN` + 1, zero-padded to 3 digits (start at `001`).
2. Copy @templates/ADR-template.md to `docs/adr/ADR-NNN-<slug>.md`, where `<slug>` is the kebab-cased title from `$ARGUMENTS`. Delete the template's instructional header block.
3. Fill **Status** (Accepted, dated today), **Context**, **Decision**, **Consequences**, **Alternatives Considered** from the current discussion. Leave a clear `TODO:` for anything you can't infer — don't invent rationale.
4. Add a one-line highlight to the **Architecture Decisions** section of `CLAUDE.md`.
5. Remind the user to commit the ADR together with the related code change.
