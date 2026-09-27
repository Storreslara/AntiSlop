# Item 13: The `spec-master` / `task-master` split (ADR-0003) — disposition

Status: FINAL (as an Open-Question spec) | Date: 2026-09-25 | Author: spec-master | Item 13 of 19
Source: Fable adversarial review 2026-09-25, Gating Complaint 6
Disposition: **OPEN QUESTION — requires a human decision.** This changes the pipeline's shape and must not be decided by the persona that would absorb the other.

## Goal

Put the three options to the operator with their consequences measured, and
record a recommendation — without acting on it.

## Declared conflict of interest

This spec is authored **by `spec-master`**, and one of the options folds
`task-master` into `spec-master`. A persona recommending that it absorb
another persona's responsibilities is not a neutral party. The recommendation
below is therefore stated with that bias declared, and the decision is
explicitly reserved for the operator. This is flagged rather than quietly
worked around.

## Context

The review's case: `task-master` describes itself as a "translator" with "no
judgment"; it is gated behind a ≥6-unit threshold; and its nine-element output
is a template. Options offered: fold it into `spec-master`, or replace it
with a script per constitution P2.

Measured 2026-09-25:

- `agents/task-master.md` is **153** source lines, rendering to **425**
  adapted lines — a 272-line inlined protocol delta, i.e. **64%** of its
  adapted prompt is shared protocol rather than role content.
- `spec-master` already emits the nine-element dispatch contract itself on
  the ≤5-unit fast path. So the capability exists in `spec-master` today, and
  the split applies only above the threshold.
- The specs in this very batch are almost all fast-path: of the 19 items,
  the large majority resolve to ≤5 units. On this evidence `task-master`
  would have been invoked for few or none of them.

**Three facts that complicate the "just fold it" reading:**

1. **`to-tickets` is a real capability, not a template.** `task-master` owns
   slicing into independently-grabbable units with declared blocking edges,
   published to a tracker. Folding the persona does not remove that work; it
   moves it into an already-large `spec-master` prompt.
2. **The separation has an audit rationale.** ADR-0003 records the split; a
   spec author who also slices and writes dispatch prompts grades more of its
   own output. That is the same Writer/Reviewer logic the whole framework
   rests on, applied one level up.
3. **P2 favours the script option, not the fold.** The constitution says
   "prefer deterministic scripts over LLM re-derivation". If the work really
   is translation with no judgment, `bin/slice.js` satisfies P2 better than
   moving it into an opus persona — and it is the only option that *reduces*
   total prompt size rather than relocating it.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-09-25 Functional scope: Q Is `task-master`'s work really judgment-free?
  → A (self-resolved): **not entirely.** It assigns each unit's `Suggested
  model` tag and orders units by blocking edges — both judgment calls. The
  "translator, no judgment" self-description is its own prose, and it
  overstates. This weakens the scriptify option relative to how the review
  presents it.
- 2026-09-25 Non-functional attributes: Q How much does the split actually
  cost? → A (self-resolved): one sonnet dispatch plus a 425-line prompt, but
  **only above the ≥6-unit threshold**, which this batch shows is rarely
  crossed. The cost is smaller than the review implies.
- 2026-09-25 External dependencies & integrations: Q Does anything else
  depend on `task-master` existing? → A (self-resolved): partially verified —
  `agents/orchestrator.md` routes to it and hard-excludes `fable` for it;
  P4 requires conditional phrasing so a project may already omit it. A full
  dependency sweep is Step 1.
- 2026-09-25 Completion / acceptance signals: Q What closes this item? → A
  (self-resolved): a recorded decision amending or affirming ADR-0003. No
  code change until then.

## Risks and dependencies

- **R1. Author bias** — see the declared conflict of interest above.
- **R2. Folding relocates cost, it does not remove it.** `spec-master` is
  already 260→556 lines adapted. Absorbing slicing would grow the persona
  whose prompt is loaded on **opus**, the most expensive tier — potentially a
  net cost *increase* despite removing a sonnet dispatch.
- **R3. P4 obligation.** Persona references must stay conditionally phrased;
  any option must leave a project that omits `task-master` working.
- **R4. Reversal cost is high.** Unlike a config flip, this reshapes the
  pipeline, the dispatch contract's ownership, and the retrieval contract.
  ADR-0003 exists precisely because this was decided deliberately once.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — line counts and the fast-path
  prevalence measured; the "no judgment" self-description checked and found
  overstated.
- P2 "Prefer deterministic scripts over LLM re-derivation": **directly
  engaged** — it favours Option B over Option A, which the review notes and
  this spec agrees with. Recorded as a principle bearing on the decision, not
  a deviation.
- P3 "Version-stamp discipline": not applicable — no file edited.
- P4 "Optional personas degrade gracefully": **load-bearing** — see R3.
- P5 "`tests/validate.sh` is the merge gate": not applicable yet.

## The decision (Open Question 1)

**Should `task-master` be folded into `spec-master`, replaced by a script, or
left as-is?**

- **A. Fold into `spec-master`.** One fewer persona, one fewer 425-line
  prompt, one fewer `Suggested model` disagreement surface. Against: relocates
  work into an opus prompt (R2), and increases how much of its own output
  `spec-master` grades (ADR-0003's rationale).
- **B. Scriptify (`bin/slice.js`).** Best P2 alignment; the only option that
  reduces total prompt size. Against: slicing is not purely mechanical —
  model tagging and ordering are judgment (see Clarifications), so a script
  would need either a judgment escape hatch or a quality regression.
- **C. Leave as-is.** Zero risk, zero work. Against: keeps a persona that the
  fast path bypasses for most specs, and leaves the review's objection
  standing.

**Recommended default: C for now, with B as the direction of travel —
explicitly not A.** Three reasons: the ≥6-unit threshold means the cost is
rarely paid at all; A relocates cost into the most expensive tier while
weakening an audit boundary; and B, while best-aligned with P2, needs the
judgment components identified before a script can replace them. Step 1
produces exactly that evidence, cheaply, without committing to anything.

*Bias note:* A is the option this author would benefit from recommending, and
it is the one being recommended against. That does not make the reasoning
correct, but the direction of the bias is worth the operator's attention.

## Step 1 — Measure the split's real cost and judgment content

**Affected files:** none modified; findings in the report.

**Acceptance criteria**
- The report states how many specs in `docs/plans/` would have crossed the
  ≥6-unit threshold, as a count and a proportion — replacing the impression
  that the split is routinely exercised with a number.
- It enumerates every `task-master` responsibility and classifies each
  `mechanical` or `judgment`, with a one-line justification — the input a
  scriptify decision needs.
- It lists every file referencing `task-master` (dependency sweep per
  Clarifications), so Option A or B's blast radius is known rather than
  estimated.
- `git status --porcelain` is empty.

## Open Questions

1. The decision above. **Requires a human decision.** No implementation is
   specced until it lands.
2. **If Option C is chosen, should the ≥6-unit threshold itself change?** The
   review calls it arbitrary. Recommended default: **leave it** — Step 1's
   count will show whether it is mis-set, and changing a threshold without
   that measurement would repeat the mistake the review is objecting to.

## Self-check

- CHK1: Does the spec declare the author's conflict of interest? — PASS
  (dedicated section plus a bias note on the recommendation).
- CHK2: Is the review's "no judgment" premise checked rather than inherited?
  — PASS (found overstated; model tagging and ordering are judgment).
- CHK3: Does the spec act before the decision? — PASS (Step 1 is measurement
  only and commits to nothing).
- CHK4: Is Option A's cost stated honestly given it is the one being
  recommended against? — PASS (R2 gives the mechanism: relocation into an
  opus prompt).
- CHK5: Does Step 1 have machine-checkable criteria despite being a research
  step? — PASS (a count, a complete classification, and a file list are each
  checkable).

## Scribe update hint

Once decided, amend or affirm ADR-0003 with the measured evidence from
Step 1, and record the ≥6-unit threshold's observed crossing rate in the
glossary — it is currently an unmeasured constant that two specs now
question.

## Dispatch contract (fast path — 1 unit now; remainder blocked on the decision)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item13-spec-master-task-master-split.md`.

### Unit: item13-1-measure-split-cost
- **Objective:** Measure threshold-crossing rate, judgment content, and dependency surface.
- **Retrieval:** Step 1.
- **Affected files:** none.
- **Ordered edits:** count specs crossing ≥6 units → classify each `task-master` responsibility → sweep references.
- **Do NOT touch:** `agents/task-master.md`, `agents/spec-master.md`, ADR-0003, `bin/`. The decision is the operator's.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** `agents/task-master.md` is 153 source → 425 adapted lines (272 inlined, 64% protocol). `spec-master` already emits the dispatch contract on the ≤5-unit fast path. Most of the 19 specs in this batch are fast-path. The "translator, no judgment" self-description is overstated — model tagging and ordering are judgment calls.
- **Escalation:** if the classification is genuinely ambiguous for a responsibility, mark it `judgment` and say why — that is the conservative direction for a scriptify decision.
