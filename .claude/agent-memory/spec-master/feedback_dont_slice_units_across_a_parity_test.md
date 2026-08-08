---
name: dont-slice-units-across-a-parity-test
description: Never slice two units at a boundary that a cross-port/cross-copy parity test straddles — the test can't be green for a subset, so one unit's validate.sh criterion becomes unsatisfiable.
metadata:
  type: feedback
---

Before slicing a plan into units, check whether any test file asserts *parity
across the copies the slice separates*. If it does, the copies must move in one
unit. A parity suite written as a single loop over its targets (shared case
bodies, shared fixture setup, shared assertions) cannot be green for a subset of
them, in either direction — moving the scripts first reddens the untouched
copies' fixtures, moving the fixtures first reddens the untouched scripts.

**Why:** on `docs/plans/2026-08-07-per-unit-review-join.md` (issues #263/#264) I
sliced the canonical hook edit and its adapter ports into two units, each
carrying `bash tests/validate.sh` as a criterion. The implementer hit a wall
mid-flight: `tests/adapter-stop-gate-parity.test.sh` drives every case from one
`for port in $PORTS` loop whose *claude* port IS the canonical script, so unit 1
could never satisfy its own final criterion. Cost: a full escalation round-trip
plus a targeted spec revision. See Self-check CHK17 in that doc.

**How to apply:** when a step's affected-files list names an adapter/mirror/copy
of a file another step edits, grep the test suite for a file that exercises both
and check whether its cases are per-target source or a shared loop. If shared,
merge the steps into one dispatchable unit (keep separate step sections and
issues for the record; what merges is the *gate*). If a merge is genuinely
impossible, the resulting red window is a constitution P5 deviation — declare it
with a pinned, machine-checkable failure set, never leave it implicit. Relates to
[[verify-own-criteria-nonvacuous]]: a criterion can be non-vacuous and still be
unsatisfiable by the unit that carries it.
