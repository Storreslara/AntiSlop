---
name: dont-slice-units-across-a-parity-test
description: Never gate a source-edit step separately from the step that regenerates/ports its shipped copy — validate.sh asserts the shipped copies, so the source step's own validate.sh criterion is unsatisfiable. Hit twice on one plan.
metadata:
  type: feedback
---

**The rule, in its general form:** a step that edits a *source* artifact and a
step that produces the *shipped copy* of it can never be gated independently on
this repo, because `tests/validate.sh` asserts the shipped copies. Merge them
into one dispatchable unit, or pin the intermediate failure set up front. This
bites in (at least) two shapes:

1. **Symmetric parity** — a suite written as one loop over its targets (shared
   case bodies, fixtures and assertions) cannot be green for a subset in
   *either* direction. Moving the scripts first reddens the untouched copies'
   fixtures; moving the fixtures first reddens the untouched scripts.
2. **Strict prerequisite chain** — a suite that asserts the shipped artifact
   against a *source-derived* expectation goes red the moment the source moves
   and has exactly one green terminal: after the render. Only one ordering is
   even possible, so the "which order" question from shape 1 doesn't arise, and
   that difference makes shape 2 easy to miss when generalizing from shape 1.

**Why:** both shapes fired on `docs/plans/2026-08-07-per-unit-review-join.md`,
found by implementers mid-flight, one escalation round-trip each.
- Shape 1, issues #263/#264: `tests/adapter-stop-gate-parity.test.sh` drives
  every case from one `for port in $PORTS` loop whose *claude* port IS the
  canonical script. Self-check CHK17 in that doc.
- Shape 2, issues #265/#266/#267: `tests/cli-backfill.test.js` asserts the
  shipped `.claude/agents/` mirrors against a section list derived from
  `templates/persona-protocol.md`, so a new canonical protocol section reddens
  it until the render lands — and constitution P2 forbids hand-editing a mirror,
  so no edit inside the source step's scope can close the window. Self-check
  CHK18.

The second one was avoidable: after fixing shape 1 I re-checked only the seam
that escalated instead of sweeping every source/shipped-copy pair in the plan.

**How to apply:** when slicing, list every pair of steps where one edits a
source (template, persona file, canonical hook script) and another edits or
regenerates its adapter/mirror/port. For each pair, grep the suites for a file
that reads the *shipped* path — then merge the pair into one dispatchable unit
(keep separate step sections and issues for the record; what merges is the
*gate*). Sweep **all** pairs in one pass, not just the one that escalated. A
merged unit takes the strictest model tag of its members and gets one review
writing PASS markers for every task-id in it. If a merge is genuinely
impossible, the red window is a constitution P5 deviation — declare it with a
pinned, machine-checkable failure set (`grep -c '^FAIL'` equal to a measured
count), never leave it implicit; and prefer a checkpoint that also guards
against *new* failures rather than merely tolerating inherited ones. Relates to
[[verify-own-criteria-nonvacuous]]: a criterion can be non-vacuous and still be
unsatisfiable by the unit that carries it.
