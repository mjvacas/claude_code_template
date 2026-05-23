---
name: llm-eval
description: Build or run a ground-truth accuracy harness for an AI/LLM feature, measuring against an authoritative reference with a pass threshold. Use when adding, changing, or validating an LLM-backed extraction/classification/generation feature.
argument-hint: "[feature or function to evaluate]"
---

Goal: never ship an AI feature on vibes — measure it against known-correct data.

1. **Find an authoritative reference.** A public dataset, a hand-curated gold set, or a deterministic oracle. Without ground truth there is no eval — say so and ask the user for a source.
2. **Build the dataset.** A list of `{ input, expected, tolerance? }` cases drawn from that source. Include edge cases (empty, malformed, ambiguous), not just the easy ones.
3. **Run the feature over every case.** For numeric outputs, compare within per-field `tolerance`; for structured/text outputs, compare with the right notion of equality (exact, set, semantic).
4. **Gate on accuracy.** Compute `passed / total`, log it, and assert a threshold (e.g. `>= 0.90`). Wire this into the test suite so regressions fail CI.
5. **Log inputs and outputs** during runs (`[LLM] Input:` / `[LLM] Response:`) so failures are debuggable and prompt changes are measurable over time.

Keep the harness provider-agnostic (call the project's `LLMProvider` interface, not a vendor SDK directly) so the same eval runs across models. See @templates/LLM_APP_DEVELOPMENT_BEST_PRACTICES.md (#testing--validation) for a worked example and the provider-agnostic pattern.
