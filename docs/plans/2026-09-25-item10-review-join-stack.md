# Item 10: Review-join / pending-review / scoped-relevance stack — disposition

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 10 of 19
**Merged: absorbs item 8** ("one-unit-at-a-time invariant vs concurrent-reviewer machinery"). Both are the same subject; item 8 has no separate spec.
Source: Fable adversarial review 2026-09-25, Gating Complaint 3 + Workflow seam 4 + reactive-complexity table
Disposition: **REJECT the "revert the chain" prescription — its premise is a conflation.** Accept the documentation defect underneath it.

## Goal

Resolve the review's claim that the protocol "claims the invariant and then
builds concurrency machinery on the assumption it's violated," and close the
real defect the claim exposes — which is documentary, not architectural.

## Context

The review's prescription: *"Pick one: either allow concurrent reviews (then
the join is needed) or forbid them (then it isn't). Right now the docs claim
both."* Verified 2026-09-25 against ADR-0016 and ADR-0028, and **the docs do
not claim both — the two statements are on different axes.**

- **"One unit at a time"** constrains how many **units** are mid-review:
  at most one. `reviewer-route-gate.sh` blocks the next gated dispatch while
  a pending-review flag stands.
- **The review-join machinery** handles multiple **reviewers on one unit**.
  ADR-0016 names the trapped case explicitly: *"an advisory second-reviewer
  dispatch (a Roast pass on an already-verdicted unit), which is forbidden to
  write a marker and has no legal exit at all."*

One unit, two reviewers — one authoritative, one advisory — satisfies the
invariant and still needs the join. These are compatible, and "pick one"
presupposes a conflict that is not there.

**ADR-0028 is not concurrency machinery at all.** Its documented cause is
`tests/marker-write.test.sh` **leaking fixture markers** into the real marker
directory, twice, 30 hours apart. Its own text: the leak *"violated the
one-unit-at-a-time invariant's premise (there is never a second unit's flag
to confuse) without violating the invariant itself."* Reverting it would
reopen a defect caused by test hygiene, not by concurrency — and one that had
already been correctly diagnosed once and abandoned before it recurred.

**The real defect, which the review's misreading is evidence for.** Nothing
in the protocol states the two-axis distinction. A careful adversarial reader
went looking and derived a contradiction that does not exist. That is a
documentation failure with a measurable cost: it very nearly produced a spec
to rip out load-bearing machinery.

**Dependency on item 1.** If item 1's probe returns `viable`, ADR-0016's
"any per-unit join must be established at dispatch time" premise is partly
wrong and a genuine simplification opens up — the review's Complaint 3 Alt B
makes exactly this point. This spec therefore **documents now and re-opens
the simplification question only on that result**, rather than deciding it
blind.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Clear
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Missing
9. Completion / acceptance signals: Clear

- 2026-09-25 Terminology consistency: Q Does "one unit at a time" mean one
  unit or one reviewer? → A (self-resolved): **one unit.** The reviewers-per-
  unit axis is unnamed anywhere, which is the defect. Step 1 names both.
- 2026-09-25 Technical constraints & tradeoffs: Q Should the stack be
  simplified as the review asks? → A (self-resolved): **not on this
  premise.** ADR-0028's cause was leaked test fixtures; ADR-0016's was a
  liveness trap for advisory reviewers. Neither is reactive sprawl. A genuine
  simplification path exists but depends on item 1's probe.
- 2026-09-25 External dependencies & integrations: Q Can the join be made
  trivial at stop time? → A (self-resolved): only if `SubagentStop` exposes
  the unit id or a transcript — unverified, and ADR-0016's measurement says
  no. Deferred to Open Question 1, gated on item 1.

## Risks and dependencies

- **R1. Do not "simplify" ADR-0028 away.** Its defect recurred **after** being
  diagnosed and abandoned once. A second abandonment would be the third
  occurrence. Criteria pin the scoping behaviour.
- **R2. Test-fixture leakage is the actual unfixed root cause.** ADR-0028
  made the symptom survivable; nothing stops
  `tests/marker-write.test.sh` from writing into the real marker directory.
  Step 2 addresses that directly — it is the one place this item should
  *add* rather than document.
- **R3. Version-stamp discipline applies** — Step 1 edits
  `templates/persona-protocol.md` and regenerates persona bodies. Bump +
  CHANGELOG.
- **R4. Trimmed propagation.** The inlined protocol block is trimmed per
  persona (`PROTOCOL_SECTIONS_BY_PERSONA`), so verify propagation only on
  personas whose row includes the Review-ownership section, and verify
  *absence* on those that drop it. Per `protocol-amendments-do-not-propagate`,
  do not assume a single edit reaches all six.
- **R5.** No prior `.fail` record known (new work); marker sweep Bash-gated
  for this persona.
- **D1.** Open Question 1 is gated on item 1's Step 3 verdict.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — both ADRs read directly; the
  conflation identified rather than inherited.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  Step 2 replaces "tests should not leak" with a mechanical guarantee.
- P3 "Version-stamp discipline": **applies** to Step 1 — see R3.
- P4 "Optional personas degrade gracefully": satisfied — reviewer references
  stay conditionally phrased; asserted in Step 1.
- P5 "`tests/validate.sh` is the merge gate": satisfied.

## Step 1 — Name the two axes in the protocol and glossary

**Affected files:** `templates/persona-protocol.md` § "Review ownership";
regenerated `.claude/persona-protocol.md` and affected persona bodies;
`CONTEXT.md`; `.claude-plugin/plugin.json`; `CHANGELOG.md`.

State plainly: at most one **unit** is mid-review; a single unit may
legitimately carry a **second, advisory reviewer** that owns no verdict and
writes no marker. Point at ADR-0016 for the second axis and ADR-0028 for
leaked-marker scoping — and say that ADR-0028's cause was leaked *test
fixtures*, not concurrency. Change no rule.

**Acceptance criteria**
- The Review-ownership section references both ADRs:
  `grep -c '0016' templates/persona-protocol.md` ≥ 1 and
  `grep -c '0028' templates/persona-protocol.md` ≥ 1.
- Propagation asserted **in both directions**: for every persona whose
  `PROTOCOL_SECTIONS_BY_PERSONA` row *includes* `Review ownership — one unit,
  one review, single owner`, the regenerated `.claude/agents/<p>.md` contains
  the new sentence; for every persona that *drops* it, the file does not. A
  one-directional check would pass vacuously if propagation silently failed.
- Wording stays conditionally phrased (P4):
  `grep -cE 'if present|otherwise' <changed region>` ≥ 1.
- `CONTEXT.md` gains distinct entries for the unit axis and the
  reviewers-per-unit axis.
- Version bumped beyond `HEAD` and named in `CHANGELOG.md`.
- `bash tests/validate.sh` exits 0.

## Step 2 — Stop tests from leaking fixtures into the real marker directory

**Affected files:** `tests/marker-write.test.sh` and any sibling test that
writes markers; possibly a shared test helper.

Make fixture markers physically unable to land in the real marker directory —
redirect test writes to a temporary directory rather than relying on cleanup,
which has now failed twice.

**Acceptance criteria**
- Running the full test suite leaves the real marker directory unchanged.
  Assert mechanically: capture a listing before and after
  `bash tests/validate.sh` and require them identical. (Use the `Read` tool or
  a `grep -r`-style read, which `reviewed-path-gate.sh` permits; a compound
  `ls`-and-pipe command naming that directory is blocked — reproduced live
  2026-09-25.)
- Non-vacuity by mutation: temporarily point a fixture write back at the real
  directory, confirm the new check **fails**, revert, confirm it passes.
  Record both observations in the ready-for-review report.
- `bash tests/validate.sh` exits 0.
- ADR-0028's scoping behaviour is untouched: `bash tests/stop-gate-blocked.test.sh`
  exits 0 with `git diff --numstat tests/stop-gate-blocked.test.sh` empty.

## Open Questions

1. **If item 1's probe returns `viable`, should the join stack be
   simplified?** The review's Complaint 3 Alt B argues that hook-authored
   markers make the join trivially known at stop time. That is true *only
   if* the stop payload can reach the unit id — the very thing item 1
   measures. Recommended default: **do not open this until item 1 Step 3
   records a verdict.** If `not-viable`, item 1's ADR records the stack as
   load-bearing and this question closes permanently. If `viable`, re-open as
   a fresh spec rather than amending this one. Requires no decision now.

## Self-check

- CHK1: Does the spec state why "pick one invariant" is rejected, rather than
  just declining it? — PASS (the two-axis analysis with ADR-0016's own
  wording).
- CHK2: Do Context and Step 1 agree that no rule changes? — PASS (both say
  documentation only).
- CHK3: Is the ADR-0028 revert refused on evidence? — PASS (documented cause
  is leaked test fixtures; the defect already recurred once after being
  abandoned).
- CHK4: Does the spec address the root cause or only the symptom? — FAIL
  (missing) — revised in place: added Step 2, which fixes the fixture leakage
  ADR-0028 only made survivable.
- CHK5: Could Step 1's propagation criterion pass vacuously? — PASS (asserts
  both directions).
- CHK6: Is item 8 accounted for rather than dropped? — PASS (merged here and
  stated in the header; item 8 has no separate spec by design).
- CHK7: Is Step 2's check runnable given the marker directory is Bash-gated
  for some personas? — PASS (the criterion names the permitted read route and
  cites the live block).

## Scribe update hint

Add distinct entries for the **unit-exclusivity axis** and the
**advisory-reviewer axis**. Amend the **review-join stamp** and any ADR-0028
entry to record that the scoping fix was caused by leaked test fixtures, not
concurrent reviewers — this is the exact misreading an adversarial reader
made, and the glossary should pre-empt it rather than leave it re-derivable.

## Dispatch contract (fast path — 2 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item10-review-join-stack.md`.

### Unit: item10-1-name-the-two-axes
- **Objective:** Document unit-exclusivity vs advisory-reviewer concurrency.
- **Retrieval:** Step 1.
- **Affected files:** `templates/persona-protocol.md`, regenerated `.claude/persona-protocol.md` + affected persona bodies, `CONTEXT.md`, `.claude-plugin/plugin.json`, `CHANGELOG.md`.
- **Ordered edits:** amend Review-ownership section → regenerate → verify propagation in both directions → glossary entries → bump → CHANGELOG.
- **Do NOT touch:** any review rule; ADR-0016 or ADR-0028 (cite, don't amend); `stop-gate-core.sh`.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** ADR-0016 names the advisory-second-reviewer liveness trap; ADR-0028's cause was `tests/marker-write.test.sh` leaking fixtures twice, 30 hours apart. The protocol block is trimmed per persona — consult `PROTOCOL_SECTIONS_BY_PERSONA` in `bin/cli.js`, don't assume all six.
- **Escalation:** if `assertNoDanglingCrossReferences` throws after the edit, report — the new sentence referenced a section some persona drops.

### Unit: item10-2-stop-fixture-leakage
- **Objective:** Make test fixture markers unable to reach the real marker directory.
- **Retrieval:** Step 2.
- **Affected files:** `tests/marker-write.test.sh` and any sibling marker-writing test; possibly a shared test helper.
- **Ordered edits:** redirect fixture writes to a temp directory → add before/after listing assertion → mutate-prove → confirm ADR-0028 tests untouched.
- **Do NOT touch:** `stop-gate-core.sh`'s scoping logic; `tests/stop-gate-blocked.test.sh`.
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** leakage occurred 2026-08-31 and again 2026-09-02 after being correctly diagnosed and abandoned once; `validate.sh` re-planted the fixtures on the second occurrence. Cleanup-based approaches have failed twice — prefer making the write physically impossible.
- **Escalation:** if a test genuinely requires the real directory, report rather than weakening the assertion.
