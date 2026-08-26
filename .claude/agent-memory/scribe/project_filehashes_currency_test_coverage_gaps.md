---
name: filehashes-currency-test-coverage-gaps
description: Two known test-robustness gaps in filehashes-currency.test.js; not security issues, noted for future maintenance
metadata:
  type: project
---

**Two known coverage gaps in filehashes-currency test (unit spec2-unitE):**

1. **Unguarded empty-fileHashes-map path** — the test would pass vacuously if the fileHashes map were ever emptied (zero entries to check). The check has no validation that the map contains expected entries before running, so an empty state passes silently rather than failing to detect the problem.

2. **Slightly-early counter increment** — the examined-count increment happens slightly before it should, which weakens the "examined === keyCount" completeness assertion. The assertion still works, but the timing of the increment makes the assertion less rigorous than it could be.

**Why:** Discovered during unit spec2-unitE review (2026-08-26) by the reviewer. Both are test-robustness nits, not security issues or bugs in the production code.

**How to apply:** These should be addressed in a future maintenance pass if the test needs strengthening. Record the unit's test file path (`tests/filehashes-currency.test.js`) if undertaking a dedicated test-hardening effort. Not blocking the merge or production use of the baseline-currency check.

**Related:** [[baseline-currency]] (the glossary entry documenting the check itself, including these known limitations).
