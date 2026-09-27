# ADR 0036: Keep `human-decision-gate.sh` as-is while `humanReviewMode` stays off

Date: 2026-09-27

Status: Accepted

## Context

Item 20 (`docs/plans/2026-09-25-item20-humanreviewmode-policy.md`) resolved
its Open Question 1 as **Option B: leave `humanReviewMode` off in this
project, accept the prompt cost as the price of a shipped feature**, and its
Step 1 (`item20-1-readme-default-clarification`) corrected the README to
distinguish the plugin's shipped default (`critical`, on) from this
project's own setting (`off`). Both are PASSed
(`.claude/reviewed/item20-1-readme-default-clarification.pass`).

Item 2 (`docs/plans/2026-09-25-item02-human-decision-gate.md`) deferred any
decision on `human-decision-gate.sh` until item 20 resolved, and named this
exact outcome as one of three superseding paths: "Item 20 → Option B (stay
off, accept cost): an ADR recording 'keep as-is', so this is not re-raised
at the next audit." This ADR is that record.

**Measured facts (item02's plan, dated 2026-09-25, unless noted):**

- `hooks/scripts/human-decision-gate.sh` is **352 lines**.
- `tests/human-decision-gate.test.sh` was **924 lines** as measured
  2026-09-25 — a 2.6:1 test-to-code ratio, consisting largely of a
  shell-lexer bypass corpus.
- `.claude/human-review/` contains **0** packets.
- `.claude/persona-config.json:111` → `"humanReviewMode": "off"`.

The gate therefore guards a path with zero live traffic in this project, and
has done since ADR-0024 turned the mode off.

## Decision

**Keep `hooks/scripts/human-decision-gate.sh` as-is. No replacement, no
removal, no conditional loading.**

This is the same rationale class as `task-gate.sh` (item 9): the gate is
correct-and-dormant, not dead weight. This repository is a plugin —
`bin/cli.js` writes `humanReviewMode: 'critical'` as the shipped default for
other adopting projects, and `agents/reviewer.md` states an absent key
resolves to `critical` (on). Removing or weakening the gate because *this*
project turned the feature off would break every other project that runs
with the mode on by default. The proportionality complaint that motivated
item 2 (352 lines to make one file unwritable) is real only relative to this
project's own zero-packet, mode-off state — it does not generalize to the
plugin's shipped posture, and the gate must not be evaluated as if it did.

**A known, separately-tracked defect is not addressed by this decision.**
`human-decision-gate.sh` has a documented prose false positive — it fires on
two bare substrings, and narrowing it to the real write target was found
impossible because the command skeletons of `git commit -m` and `sh -c` are
identical. This is tracked by prior work (the `hdg-prose-2` debug spec) and
is explicitly out of scope here; this ADR neither fixes it nor treats it as
resolved.

## Re-open trigger

This decision is tied to item 20's disposition, not independently reasoned.
**If item 20's decision changes** — the mode is turned on (Option A), or
conditional loading or removal is chosen (Option C/D) — **this ADR is
superseded** by whichever of item 2's other two named outcomes applies:

- Mode turned on → a replacement spec that must preserve the sanctioned
  `rm -rf .claude/human-review/<task-id>` deletion path and close the known
  prose false positive (`permissions.deny` is not a drop-in: it would also
  block that sanctioned deletion, per item 2's R1).
- Conditional loading or removal chosen → a removal spec that must also
  retire the 924-line (as of 2026-09-25) test corpus.

Absent such a change, this "keep as-is" disposition stands and should not be
re-raised at the next audit as a fresh question.

## Consequences

- No code, test, or config change results from this ADR. It is a
  documentation-only disposition, matching item 2's own deferred-item
  contract.
- The next audit that encounters `human-decision-gate.sh`'s size relative to
  its live traffic should find this ADR before re-deriving the same
  proportionality complaint from scratch.
- The prose false positive remains open, tracked elsewhere, and is not
  reopened, closed, or restated as resolved by this record.

## Related

- [ADR-0024](0024-ceremony-reduction-solo-operator.md) — turned
  `humanReviewMode` off for this project; this ADR's "keep as-is" disposition
  presupposes that setting stands.
- [ADR-0018](0018-human-in-the-loop-review-on-by-default.md) — the
  human-in-the-loop review this gate protects, on by default for the plugin.
- `docs/plans/2026-09-25-item02-human-decision-gate.md` — the deferred spec
  this ADR closes (Item 20 → Option B outcome).
- `docs/plans/2026-09-25-item20-humanreviewmode-policy.md` — the decision
  this ADR's re-open trigger is keyed to.
