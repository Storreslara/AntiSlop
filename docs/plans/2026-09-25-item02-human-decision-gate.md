# Item 02: `human-decision-gate.sh` simplification

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 2 of 19
Source: Fable adversarial review 2026-09-25, Gating Complaint 2
Disposition: **DEFER — blocked on item 20.** The gate guards a feature that is currently switched off; its implementation should not be decided before the feature's fate is.

## Goal

Record the disposition and the evidence for `human-decision-gate.sh`'s 352
lines, and state precisely what must be decided before any replacement is
specced.

## Context

The review proposes replacing the gate with either Claude Code
`permissions.deny` entries, or by moving the DECISION file outside the repo
tree so a cwd-relative write cannot reach it.

Measured 2026-09-25:

- `hooks/scripts/human-decision-gate.sh` is **352 lines**.
- `tests/human-decision-gate.test.sh` is **924 lines** — a 2.6:1 test-to-code
  ratio, consisting largely of a shell-lexer bypass corpus.
- `.claude/human-review/` contains **0** packets.
- `.claude/persona-config.json:111` → `"humanReviewMode": "off"`.

So the gate currently protects a path with **zero live traffic**, and has done
since ADR-0024 turned the mode off.

**Why this is deferred rather than accepted.** The review's own framing is
right that 352 lines to make one file unwritable is disproportionate — but the
proportionality depends entirely on whether the feature it guards is wanted:

- If item 20 chooses to **turn the mode on**, the gate becomes live and its
  replacement must be at least as strong. `permissions.deny` is coarser and
  would also block the *sanctioned* `rm -rf` packet deletion the reviewer
  performs, so adopting it requires relocating packet deletion into a hook or
  `bin/` first — real work, not a config line.
- If item 20 chooses to **leave it off**, the cheapest correct action may be
  neither replacement: a gate on a dead path costs nothing at runtime, and
  its cost is the 924-line test corpus's maintenance, not tokens.
- If item 20 chooses **conditional loading or removal**, the gate may become
  removable outright.

Deciding the gate's implementation before deciding the feature's fate would
be solving the wrong problem in the most expensive order.

**One independent finding worth recording now.** This project's own memory
records that `human-decision-gate.sh` produces a **prose false positive** —
it fires on two bare substrings, and "narrow it to the real write target" was
found impossible because the command skeletons of `git commit -m` and `sh -c`
are identical. That is a known, shipped defect in the current gate, and it
strengthens the case for replacement *whichever* way item 20 goes. It is
already tracked by prior work (`hdg-prose-2` debug spec) and is **not**
re-specced here — noted so this item is not mistaken for the whole story.

## Clarifications

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Clear
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-09-25 Functional scope: Q Can the gate's replacement be specced now? →
  A (self-resolved): **no** — its required strength depends on item 20's
  answer. Deferring is the disposition, not an omission.
- 2026-09-25 Edge cases / failure handling: Q Does `permissions.deny` cover
  the sanctioned deletion path? → A (self-resolved): **no** — it would also
  block the reviewer's sanctioned `rm -rf` of a resolved packet, which the
  reviewer is explicitly instructed to perform. Any `permissions.deny`
  adoption must relocate packet deletion first.
- 2026-09-25 Non-functional attributes: Q Is the gate a runtime cost? → A
  (self-resolved): negligible at runtime; its real cost is the 924-line
  bypass-corpus test burden and the prose false positive.
- 2026-09-25 Completion / acceptance signals: Q What closes this item? → A
  (self-resolved): item 20's decision, followed by either a replacement spec
  or an explicit "keep as-is" recorded in an ADR.

## Risks and dependencies

- **R1. Do not adopt `permissions.deny` as a drop-in.** It is coarser and
  would break the sanctioned deletion path (see Clarifications). The review
  acknowledges this; it must not be lost in a later summary.
- **R2. The out-of-tree DECISION alternative changes the human's workflow**,
  not just the implementation — the packet and its decision stop being
  co-located. That is a usability decision for the operator, not an
  engineering cleanup.
- **R3. A known prose false positive already exists** and is separately
  tracked; do not re-spec it here, and do not treat this item as superseding
  it.
- **D1. Blocked on item 20.**

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — line counts, packet count and mode
  measured rather than quoted.
- P2 "Prefer deterministic scripts over LLM re-derivation": not applicable —
  nothing is derived here.
- P3 "Version-stamp discipline": not applicable — no file is edited.
- P4 "Optional personas degrade gracefully": noted — the gate must keep
  behaving correctly for a project that selects a reviewer and leaves
  `humanReviewMode` absent (which resolves to `critical`, i.e. on).
- P5 "`tests/validate.sh` is the merge gate": not applicable — no change.

## Steps

**None.** This item is deferred by design; it has no dispatchable unit until
item 20 resolves. Recording a deferral with its evidence and its unblocking
condition *is* this spec's deliverable, per the requirement that no item be
silently dropped.

When item 20 resolves, this spec is superseded by one of:

- **Item 20 → Option A (mode on):** a replacement spec that must preserve the
  sanctioned deletion path and close the known prose false positive.
- **Item 20 → Option B (stay off, accept cost):** an ADR recording "keep
  as-is", so this is not re-raised at the next audit.
- **Item 20 → Option C/D (conditional or removed):** a removal spec, which
  must also retire the 924-line test corpus.

## Open Questions

1. **Blocked on item 20** — see that spec's Open Question 1. No independent
   decision is available here.
2. **If the mode stays off, is "keep as-is" acceptable, or should the gate be
   removed as dead weight?** Recommended default: **keep as-is and record an
   ADR.** The gate is correct-and-dormant in the same sense as
   `task-gate.sh` (item 9): this is a plugin, and other projects run with the
   mode on by default, so removing it would break them. Removing a correct
   guard because *this* repo disabled the feature would be the mirror image of
   the reactive complexity the review objects to.

## Self-check

- CHK1: Does the spec state a disposition rather than silently dropping the
  item? — PASS (DEFER, with the unblocking condition and the three
  superseding outcomes named).
- CHK2: Is the `permissions.deny` alternative evaluated rather than repeated?
  — PASS (its incompatibility with the sanctioned deletion path is stated).
- CHK3: Is the known prose false positive accounted for? — PASS (recorded,
  attributed to prior tracked work, explicitly not re-specced).
- CHK4: Does the spec have machine-checkable criteria? — FAIL (missing) —
  it has no steps, so none are possible. Converted to Open Question 1: the
  item cannot produce checkable criteria until item 20 resolves, and a
  criterion invented now would be one nobody could run. This is the
  documented exception, not an oversight.
- CHK5: Could "defer" here hide a live risk? — PASS (the guarded path has 0
  packets and the mode is off, so deferral carries no live exposure).

## Scribe update hint

No new term. When item 20 resolves, record the outcome against the existing
`humanReviewMode` and decision-gate entries, and note the 0-packet /
mode-off evidence so the next audit does not re-derive it.

## Dispatch contract

**None — no units.** This spec is a recorded deferral. Re-dispatch only after
item 20's decision, at which point one of the three superseding specs above is
authored.

Retrieval contract (for the future spec):
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item02-human-decision-gate.md`.
