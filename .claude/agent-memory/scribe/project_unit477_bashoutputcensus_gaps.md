---
name: unit477_bashoutputcensus_gaps
description: Unit #477 (cost-governance-step1-bash-census) known gaps and non-blocking items
metadata:
  type: project
---

**Unit:** cost-governance-step1-bash-census, issue #477

**Status:** PASS (after 1 FAIL/fix cycle). Final commit: 560ca87

## Non-blocking gap (documentation only)

`tests/bash-output-census.test.js` is not wired into `tests/validate.sh`'s sweep, unlike every other fixture-based test in this repo (which follow a three-line `if node tests/X.test.js; then … fi` pattern, e.g. `tests/validate.sh:343` for `filehashes-currency.test.js`).

**Effect:** The new test currently only runs when invoked by hand and isn't protected by the merge gate.

**Out of scope:** This gap is a maintenance item for a future unit; documentation of unit #477's known limitations only. No fix required in this dispatch.

**Recording:** This doc serves as a known-gaps reference for future merge-gate hardening work.
