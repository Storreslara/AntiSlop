---
name: amend-in-place-coordination-pattern
description: When a new spec supersedes only part of an already-open, not-yet-started issue, edit that issue's body in place (not a split-off sibling) plus a dated coordination comment and a cross-label
metadata:
  type: project
---

When a finalized spec amends only a **sub-part** of an already-open, not-yet-
built issue (e.g. one flow step of a multi-part unit), and the amendment is a
straight textual supersession rather than new additional scope, prefer
**editing that issue's body in place** over filing a new sibling issue with a
"see the new issue" pointer comment.

Precedent: `docs/plans/2026-08-11-human-decision-channel.md` Step 3 amends
only flow step 3 of #136 (Step 7 of the 2026-07-28 human-review plan). #136
was still open and unstarted (no lead-programmer dispatch, no `.fail`
record), so there was no risk of clobbering in-flight work. Applied:
- `gh issue edit 136 --body-file ...` replacing the superseded flow-step-3
  text and its dependent sections (Rationale's architectural-constraint
  paragraph, the Routes table's Approve/Reject/Direct cells, Affected files,
  Acceptance criteria) with the amended content, clearly marked inline with
  an `> **AMENDED <date> (task-master):**` blockquote at the top explaining
  what changed and pointing at the amendment's spec doc + PRD issue.
- `gh issue edit 136 --title "... (amended by #324 — <one-line-what-changed>)"`
  so the title itself signals the amendment to anyone scanning `gh issue
  list`.
- `gh issue comment 136` with a dated `AMENDED <date> (task-master,
  follow-up):` note (same phrasing convention as the split-off pattern in
  [[project_convergence_followup_label_reuse]]'s #137/#138 precedent) —
  even though the body was edited directly, the comment preserves an audit
  trail of *when* and *why*, since GitHub issue body edits are not
  separately versioned in the issue timeline the way comments are.
- Added the **new** spec's `plan/<slug>` label to the amended issue
  *in addition to* its original label (both kept), so
  `gh issue list --label plan/<new-slug>` surfaces the amended issue
  alongside the new spec's own freshly-filed sibling units, without losing
  `gh issue list --label plan/<original-slug>`'s completeness for the
  original plan.
- Updated the issue's own `Depends on / blocked by` line to add the new
  spec's units as additional blockers, since the amended text now
  references mechanisms (e.g. a new hook) that must exist first.

**Contrast with the split-off pattern** ([[project_convergence_followup_label_reuse]],
#137/#138 → #322/#323): that pattern is for **additive** new scope on top of
already-scoped-and-standing work, where leaving the original body untouched
and adding a new sibling with a pointer comment keeps both units
independently gradable. Use amend-in-place instead when the new spec
**replaces** a description already sitting in an unstarted issue, since a
stale relay-based instruction left in the body would actively mislead
whichever `lead-programmer` picks it up next — a pointer comment is not
enough to prevent that misread.

**Why:** the deciding factor is whether the original issue's on-disk body
text, if left unedited, would give a future executor **wrong instructions**
(amend-in-place) versus merely **incomplete** ones that a sibling issue can
supply without contradiction (split-off).

**How to apply:** before choosing, check whether the target issue has
already been dispatched/built (`.claude/reviewed/<id>.fail` or `.pass`
existing, or any lead-programmer activity referencing it) — amend-in-place
is safe pre-dispatch; once work is in flight, prefer a coordination comment
plus a new issue instead, to avoid rewriting instructions out from under an
agent mid-task.
