---
name: rollout-a24-deadvars-fix-gaps
description: Two non-blocking minor gaps noted during rollout-a24-deadvars-fix review; deferred maintenance items
metadata:
  type: project
---

**Two non-blocking review notes from rollout-a24-deadvars-fix (PASS 2026-09-23):**

The unit removed dead local variables `checked` and `failed` from `scripts/rollout-preflight.sh`'s `reverify_spec6()` function, updating its summary output from `Summary: checked=$checked, skipped=$skipped, failed=$failed` to `Summary: skipped=$skipped`, and replacing the vacuous `[ "$failed" -eq 0 ]` check with `return 0`. No behavioral change (exit code remains always-0 in practice).

**Minor gap 1 — unreachable grep alternative:**
File: `tests/rollout-preflight.test.sh:273`
- Current: `grep -qE "checked|skipped"`
- Issue: The `checked` alternative is now unreachable since the summary string no longer contains that word
- Future cleanup: tighten to `grep -q "skipped"`

**Minor gap 2 — missing re-mechanization comment:**
File: `scripts/rollout-preflight.sh:434`
- Current: bare `return 0` with no explanatory comment
- Issue: A future re-mechanization of A24/A13 into a real check will need to reintroduce failure accounting. The unconditional success return should be annotated to note this invariant.

**Why:** Discovered by reviewer during rollout-a24-deadvars-fix review (2026-09-23). Both are informational notes, not blocking findings.

**How to apply:** Address in a future maintenance pass for the rollout-preflight test suite and A24/A13 skip logic. Not required for this unit or its merge. Record these file paths if undertaking a dedicated test-hardening or skip-mechanism review.

**Related:** [[flip unit]], [[treadmill]] (glossary entries documenting A24's skip design); rollout-a24-remechanize-1 (prior unit introducing the skip pattern).
