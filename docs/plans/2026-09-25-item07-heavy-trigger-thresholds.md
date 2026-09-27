# Item 07: `heavy-trigger.sh` thresholds vs ADR-0004 as sole source of truth

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 7 of 19
Source: Fable adversarial review 2026-09-25, Workflow seam 2
Disposition: **PARTIALLY REJECT — the claimed contradiction does not exist; a different, real drift risk does.** Add a drift check; keep the hardcode.

## Goal

Close the genuine defect behind this item — two unlinked copies of the same
thresholds — without performing the change the review actually asked for,
which rests on a misreading.

## Context

The review's claim: *"'Defined in one place by pointer' is false for the
heavy-unit trigger. `reviewer.md:203-206` and `persona-protocol.md:343-347`
insist thresholds are read from ADR-0004, 'never from a local restatement' —
and `heavy-trigger.sh:19-20` hardcodes 8 / 400."*

**Verified 2026-09-25, and the contradiction does not hold.** Both documents
explicitly *sanction* the script:

- `templates/persona-protocol.md` § "Measured heavy-unit surface": the
  script's result *"mechanizes one of the three ANY-of criteria the ADR-0004
  pointer above defines — criterion 1, the changed-surface size."*
- `agents/reviewer.md`: same, *"it mechanizes criterion 1 only, so
  `surface: light` means just that criterion 1 is not met (criteria 2 and 3
  stay your judgment)."*
- `heavy-trigger.sh`'s own header: *"Measures ADR-0004 criterion 1 only.
  Deliberately does NOT measure criteria 2… or 3."*

The instruction "read the thresholds there, never from a local restatement"
is addressed to a **reader deciding which prose to trust**, not a prohibition
on mechanizing criterion 1 in a script. Removing the hardcode would delete the
measurement the protocol requires the reviewer to run.

**The real residual, which the review did not name.** `MIN_CHANGED_FILES=8`
and `MIN_CHANGED_LINES=400` (`heavy-trigger.sh:19-20`) are a second copy of
ADR-0004's numbers with **no mechanical link**. Amending the ADR's thresholds
would leave the script silently disagreeing — the exact failure mode the
pointer doctrine exists to prevent, arriving by a different route. That is
worth closing, and a drift check closes it.

**A trap this spec must avoid, already paid for once.** The
`heavy-trigger-not-in-protocol` memory note records that a prior spec shipped
the criterion ``grep -c '≥ ~8 impacted files' templates/persona-protocol.md``
is 1 — false twice over: no such protocol section exists, and the ADR's bytes
are `≥~8` **unspaced**, so the spaced-form grep matched nothing anywhere. Any
criterion here must compare numbers, not glyphs, and must not push a
restatement into the protocol.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-09-25 Technical constraints & tradeoffs: Q Remove the hardcoded
  thresholds, or link them? → A (self-resolved): **link them.** The hardcode
  is the sanctioned mechanization of criterion 1; removing it deletes a
  required measurement. The defect is the unlinked duplication.
- 2026-09-25 Edge cases / failure handling: Q The ADR writes `≥~8` with a
  tilde ("approximately"). Can an exact equality check be justified? → A
  (self-resolved): the script must pick exact integers to be deterministic, so
  the check asserts the script's integers equal the ADR's stated integers,
  treating `~` as prose hedging rather than a tolerance. If a future ADR
  amendment intends a range, that is a spec change, not a check failure —
  flagged in Open Question 1.
- 2026-09-25 Terminology consistency: Q Is "heavy-unit trigger" one criterion
  or three? → A (self-resolved): **three ANY-of criteria**, of which the
  script measures only #1. Existing glossary has 3 hits for "heavy-unit
  trigger"; Step 2 verifies they say ANY-of-three, not "the 8/400 rule".

## Risks and dependencies

- **R1. Glyph-matching trap.** See Context. Compare parsed integers, never
  the `≥~` string.
- **R2. Do not restate the trigger in the protocol.** A criterion asserting
  `grep -c 'impacted files' templates/persona-protocol.md` is **0** is
  included precisely to prevent a well-meaning implementer from "helpfully"
  copying the thresholds into the protocol.
- **R3. Mirror multiplication** — `heavy-trigger.sh` has mirror copies;
  `validate.sh` asserts parity. No script change is planned, but the test
  harness must reference the right copy.
- **R4. ADR-0004 is a palimpsest**, amended by 0006, 0009 and 0013, and still
  contains a superseded line (*"Task-master tags heavy units with `Roast pass:
  fable`"*, removed in substance by ADR-0013). The parser must read the
  current threshold statement, not a superseded one — Step 1 must state which
  line it parses.
- **R5.** No prior `.fail` record known (new work); marker sweep Bash-gated.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the alleged contradiction was
  checked against all three sources and falsified.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — a
  mechanical drift check replaces a doctrine enforced only by prose.
- P3 "Version-stamp discipline": deviation — Step 1 touches tests only;
  `heavy-trigger.sh` constants are unchanged and no version-stamped file is
  edited. Step 2 touches `CONTEXT.md`, which is not version-stamped. If an
  implementer's diff reaches `agents/*.md` or templates, P3 re-applies.
- P4 "Optional personas degrade gracefully": satisfied — untouched.
- P5 "`tests/validate.sh` is the merge gate": satisfied.

## Step 1 — Add a threshold drift check

**Affected files:** `tests/heavy-trigger.test.sh` and/or `tests/validate.sh`.
**No change** to `heavy-trigger.sh`'s constants.

Parse the threshold integers from ADR-0004's current "Heavy unit trigger"
statement and assert they equal `MIN_CHANGED_FILES` and `MIN_CHANGED_LINES`.

**Acceptance criteria**
- The test passes on the unmutated tree, and `bash tests/heavy-trigger.test.sh`
  exits 0.
- Non-vacuity proven by mutation, **both directions**: (a) set
  `MIN_CHANGED_FILES=9` → the test **fails**; revert → passes. (b) change the
  ADR's stated file threshold to 9 → the test **fails**; revert → passes.
  Both observations recorded in the ready-for-review report. Direction (b)
  is what proves the check reads the ADR rather than only the script.
- The check compares parsed integers: it passes regardless of whether the ADR
  writes `≥~8` or `≥ ~8` — assert by temporarily inserting a space and
  confirming the test still passes.
- The test's source names the exact ADR line it parses (a comment naming the
  heading), so R4's palimpsest risk is visible to the next reader.
- `grep -c 'impacted files' templates/persona-protocol.md` is **0** — no
  restatement was introduced.
- `bash tests/validate.sh` exits 0.

## Step 2 — Verify the glossary describes three criteria, not one

**Affected files:** `CONTEXT.md` (only if it misstates the trigger).

**Acceptance criteria**
- Every `CONTEXT.md` occurrence of the heavy-unit trigger describes it as
  **ANY-of-three** criteria and does not present 8/400 as the whole rule;
  assert by reading each of the 3 current hits and reporting the disposition
  of each in the ready-for-review report.
- If no change is needed, the unit reports "no change warranted" with the
  three dispositions — this is a valid completion, not a failure to act.
- `bash tests/validate.sh` exits 0.

## Open Questions

1. **Is `~` in ADR-0004's thresholds meant as a tolerance or as prose
   hedging?** The script must pick exact integers, so today it reads as
   hedging. If a future amendment intends "approximately 8, reviewer
   discretion either side", the drift check would need a tolerance rather than
   an equality. Recommended default: **treat as prose hedging and assert
   equality** — the script is already exact, so this records existing
   behaviour rather than changing it. Worth a one-line ADR-0004 clarification
   if a human disagrees; not worth blocking this spec.

## Self-check

- CHK1: Does the spec avoid the exact criterion shape that failed before? —
  PASS (compares parsed integers; explicitly asserts space-insensitivity; does
  not grep a threshold string against the protocol).
- CHK2: Do Context and Step 1 agree that the hardcode stays? — PASS (both
  state the constants are unchanged).
- CHK3: Could the drift check pass while only reading the script? — FAIL
  (missing) — revised in place: Step 1 now requires mutation direction (b),
  mutating the **ADR**, which is the only way to prove the check reads both
  sides.
- CHK4: Is R2's restatement risk enforced by a criterion or only by prose? —
  PASS (explicit `grep -c 'impacted files' … is 0`).
- CHK5: Does Step 2 permit a legitimate no-op outcome? — PASS (explicitly, so
  the unit is not pressured to manufacture a diff).

## Scribe update hint

Add a **heavy-trigger threshold drift check** entry. Confirm the existing
**heavy-unit trigger** entry states ANY-of-three and points at ADR-0004 as
amended by ADR-0013 — and that it does not present the script as the
definition of the trigger, which is the misreading this item began as.

## Dispatch contract (fast path — 2 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item07-heavy-trigger-thresholds.md`.

### Unit: item07-1-threshold-drift-check
- **Objective:** Mechanically link script constants to ADR-0004's thresholds.
- **Retrieval:** Step 1.
- **Affected files:** `tests/heavy-trigger.test.sh` and/or `tests/validate.sh`.
- **Ordered edits:** locate the current ADR threshold statement → parse integers → compare to script constants → prove by mutation in both directions → confirm space-insensitivity.
- **Do NOT touch:** `heavy-trigger.sh`'s constants or any of its logic; `templates/persona-protocol.md`.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** constants are `MIN_CHANGED_FILES=8`, `MIN_CHANGED_LINES=400` at `heavy-trigger.sh:19-20`. ADR bytes are `≥~8`/`≥~400` **unspaced** — a prior spec's spaced-form grep matched nothing anywhere. ADR-0004 is amended by 0006/0009/0013 and still contains a superseded `Roast pass: fable` line; parse the current threshold statement only.
- **Escalation:** if the ADR's threshold statement is ambiguous enough that no single integer can be parsed, report rather than choosing one silently.

### Unit: item07-2-glossary-trigger-check
- **Objective:** Confirm the glossary states ANY-of-three, not the 8/400 rule alone.
- **Retrieval:** Step 2.
- **Affected files:** `CONTEXT.md` (only if misstated).
- **Ordered edits:** read each of the 3 heavy-unit-trigger hits → report disposition of each → amend only what misstates.
- **Do NOT touch:** ADR-0004; the script.
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** `grep -c` for the trigger in `CONTEXT.md` returned 3 hits (measured 2026-09-25). "No change warranted" is an acceptable outcome if all three are already correct — do not manufacture a diff.
- **Escalation:** none expected; if a glossary entry contradicts ADR-0004 outright, report it rather than reconciling on your own authority.
