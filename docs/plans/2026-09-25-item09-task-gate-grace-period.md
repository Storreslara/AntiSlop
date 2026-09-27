# Item 09: Delete `task-gate.sh`'s expired grace-period branch

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 9 of 19
Source: Fable adversarial review 2026-09-25, reactive-complexity table (`GRACE_PERIOD_END`)
Disposition: **ACCEPT — delete.** Confirmed dead code.

## Goal

Remove the expired v0.6.0 legacy-marker grace-period branch from
`hooks/scripts/task-gate.sh` and its mirror copies, without touching any
behaviour that is merely dormant rather than dead.

## Context

Verified 2026-09-25:

- `GRACE_PERIOD_END="2026-07-27"` at `task-gate.sh:35`.
- Branched on at line 95: `[[ "$today" < "$GRACE_PERIOD_END" ]]`.
- Referenced in messages at lines 74 and 81, and in a header comment at 16.
- The date passed two months ago, so the branch is unreachable and the two
  messages are unreachable text.

**One distinction the review blurs and this spec does not.** The review notes
that `task-gate.sh` "only runs on `TaskCompleted`, which only exists in
agent-teams mode, which `.claude/settings.json` sets to `0`" — implying the
whole file is dead. It is not: agent-teams mode is a supported gear
(`antislop:start-feature-team`), so the gate is **correct-and-dormant**.
Deleting the file would break that mode. Scope is the expired branch only.

Also out of scope: `marker_valid()` and v2-marker acceptance. Those live in
the same file but are **not** part of the grace period — the shared protocol
states v2 markers "remain valid and are never retroactively rejected". A
diff that removes them would be a regression wearing a cleanup's clothes.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-09-25 Edge cases / failure handling: Q Should the whole of
  `task-gate.sh` be removed, since `TaskCompleted` never fires in this
  project's current mode? → A (self-resolved): **no** — dormant is not dead;
  agent-teams mode is a supported gear. Scope is the expired branch only.

## Risks and dependencies

- **R1. Mirror multiplication.** `task-gate.sh` exists in `hooks/scripts/`
  plus mirrors under `.claude/hooks/scripts/` and both adapters. `validate.sh`
  asserts mirror parity and `bin/cli.js` carries `fileHashes`, so this is a
  multi-artifact change. Confirm the mirror set at execution time; per the
  `validate-sh-is-a-mirror-parity-check` memory note a hand-rolled hash check
  must `stripStamp` first — prefer `validate.sh`.
- **R2. Collateral-deletion risk.** `marker_valid()` sits nearby. The
  acceptance criteria pin it explicitly so its removal cannot pass review.
- **R3.** No prior `.fail` record known (new work); the marker-directory sweep
  is Bash-gated for this persona, so treat as unverified rather than clean.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — line numbers and the dormant-vs-dead
  distinction re-measured.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — no
  hand-edit of a script-driven path; mirrors propagate via the normal route.
- P3 "Version-stamp discipline": deviation — `hooks/scripts/*.sh` is not a
  version-stamped file (`agents/*.md`, templates). If the implementer's diff
  reaches a version-stamped file, P3 re-applies.
- P4 "Optional personas degrade gracefully": satisfied — untouched.
- P5 "`tests/validate.sh` is the merge gate": satisfied — asserted.

## Step 1 — Remove the grace-period branch

**Affected files:** `hooks/scripts/task-gate.sh` + every mirror copy
(confirm set at execution time).

Delete the `GRACE_PERIOD_END` constant, the date comparison branch, the two
messages referencing it, and the now-stale header sentence. Keep every other
behaviour.

**Acceptance criteria**
- `grep -rc 'GRACE_PERIOD' hooks/scripts/task-gate.sh` is **0**, and 0 in
  every mirror copy (assert per-copy, not just the source).
- `marker_valid()` survives: `grep -c 'marker_valid' hooks/scripts/task-gate.sh`
  is ≥ 1.
- v2 markers still accepted — existing task-gate tests pass **unchanged**:
  `git diff --numstat tests/` produces no output for any task-gate test file.
- `bash tests/validate.sh` exits 0 (this is also the mirror-parity assertion).
- Non-vacuity of the mirror check: confirm at least one mirror path was
  actually edited by reporting the list of changed files in the
  ready-for-review report.

## Open Questions

None. The code is unreachable by date, the scope boundary is settled, and the
retained behaviour is pinned by criteria.

## Self-check

- CHK1: Does the spec distinguish the dead branch from the dormant file? —
  PASS (Context and the Clarifications entry both state it; Step 1 scopes to
  the branch).
- CHK2: Is `marker_valid()` protected by a criterion rather than by prose? —
  PASS (explicit `grep -c ... ≥ 1`).
- CHK3: Is the mirror set asserted rather than assumed? — FAIL (ambiguous) —
  revised in place: Step 1 now says "confirm set at execution time" and
  requires the changed-file list in the report, instead of naming a count
  this spec did not measure for this file.
- CHK4: Could the v2-marker criterion pass vacuously if the tests were edited?
  — PASS (the criterion asserts the test files have a zero-line diff).

## Scribe update hint

No new glossary term. If a **grace period** entry exists in `CONTEXT.md`,
mark it retired with the date, rather than deleting it — the repo's
convention for retired terms is an in-place retirement note (see the existing
`[Retired in 0.28.0; see review-join stamp below.]` entry).

## Dispatch contract (fast path — 1 unit)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item09-task-gate-grace-period.md`.

### Unit: item09-1-delete-grace-period
- **Objective:** Remove the expired v0.6.0 grace-period branch.
- **Retrieval:** Step 1.
- **Affected files:** `hooks/scripts/task-gate.sh` + mirrors.
- **Ordered edits:** confirm mirror set → delete constant, branch, two messages, stale header line → propagate to mirrors → `validate.sh`.
- **Do NOT touch:** `marker_valid()`; v2-marker acceptance; any test file; the file itself (it stays).
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** constant at line 35, branch at line 95, messages at 74 and 81, header at 16 (measured 2026-09-25). The gate is dormant, not dead — agent-teams mode is supported via `antislop:start-feature-team`.
- **Escalation:** if a test depends on the grace branch, report it rather than editing the test to suit the change.
