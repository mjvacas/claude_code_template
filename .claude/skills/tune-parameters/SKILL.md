---
name: tune-parameters
description: Choose a threshold or parameter by reading the shape of the metric surface across a sweep, not by grabbing the single best grid cell. Use whenever picking a numeric knob (threshold, weight, window size, learning rate).
argument-hint: "[parameter and range to sweep]"
---

Goal: pick a parameter that is *robust*, not overfit to noise.

1. **Sweep, don't guess.** Vary the parameter ($ARGUMENTS if given) across a sensible grid. Record the target metric at each point. Don't hand-pick a value and don't stop at the first good number.
2. **Read the surface shape:**
   - **Smooth** — metric changes gradually as you vary the knob → a real effect. Pick a robust point in the *middle* of the good region, not its edge.
   - **Lone spike** — one great cell with worse cells all around it → overfit to noise. Discard it.
3. **Validate across the full history / dataset**, not just the recent or easy regime. A value that only holds under current conditions will break when conditions change.
4. Report: the chosen value, the shape you observed (smooth region vs. spike), and the range over which the metric stays acceptable (the safety margin).

Anti-patterns to flag if you see them: `argmax` over a noisy grid; tuning and validating on the same slice; a threshold justified by a single impressive data point.
