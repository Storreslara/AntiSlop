---
name: vacuous_sweep_conversion_pattern
description: Vacuous differential sweeps are converted to block-direction cases with allow-controls per Amendment A5
metadata:
  type: project
---

## Vacuous differential-sweep pattern and the Amendment A5 remedy

**Fact:** When a differential-sweep test case is found to be effectively vacuous (unreachable divergence — the gate cannot fail the case regardless of its behavior because the test scenario itself is unrealizable), the repo's documented policy is to convert it from a differential form to a one-directional block assertion with an explicit mutation control, rather than leaving it in partial form.

**Why:** 
A differential sweep that never fails regardless of gate behavior is a vacuous criterion — it proves nothing. In this repo's case, unit #270 found that cases 26's T3/T4 templates could not possibly write into the marker directory through the two redirection exemptions, regardless of gate state (three independent measurements proved this). Keeping such tests wastes coverage budget and creates a false sense of thorough measurement. The honest form is a one-directional block (proving the gate blocks when it should) with an explicit mutation control (proving the gate actually changes behavior in the block direction).

**How to apply:** 
When a differential sweep's effect is genuinely unobservable across all probes (measured via whole-sandbox `find` diff before/after, not inferred from exit codes), convert the case to a block-direction case modeled on the repo's existing one-directional block pattern (e.g., case 30 in `tests/reviewed-path-gate.test.sh`). Use an allow-control to bound the over-block, and include a documented mutation control (with correct shell escaping from the canonical spec doc). Record the before/after probe counts in the diff so the coverage arithmetic remains auditable: the sum of all template counts should be conserved.

**Reference:** Amendment A5 of `docs/plans/2026-07-31-reviewed-path-gate-write-intent.md:882-884` prescribes this fix shape for exactly this scenario. Unit #270 was the second time this pattern was applied to this repo's test suite (first was `git`/`rg` removal from the allowlist in #186). This is a standing repo policy.
