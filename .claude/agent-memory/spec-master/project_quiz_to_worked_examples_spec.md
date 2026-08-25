---
name: quiz-to-worked-examples-spec
description: Settled decisions for replacing the escalation packet's comprehension quiz with worked examples (2026-08-20 spec), plus 3 premise corrections the dispatching brief got wrong
metadata:
  type: project
---

Spec: `docs/plans/2026-08-20-quiz-to-worked-examples.md` — 4 units
(`examples-1..4`), fast path, no `task-master`.

**Settled by the operator (all "option A"):**
- The approve-route attestation is **renamed, not deleted**:
  `examples: reviewed | skipped | none-offered`. The point is preserving what
  gh300 built — approve is the only DECISION route completable without
  demonstrating engagement, so it cannot become name-only again.
- An "example" is a **behavioural before/after** ("before this change X did Y;
  after, X does Z"), inheriting the quiz's consequence-not-recall discipline.
- "When needed" = the change has an **observable behavioural consequence**;
  skipped for pure docs/formatting/comment/rename, with the reviewer logging
  `examples: none — <reason>` on the `.escalated` marker so a skip is auditable
  rather than a bare token.

**Why the quiz was there (don't lose this if the spec is revisited):** the
protocol calls it a *speed regulator*, not comprehension material — friction the
human owes, not material the reviewer gives. Examples invert the direction, so
swapping them straight across silently drops the property unless the token
survives. That inversion was the one genuinely blocking Open Question.

**Three premise corrections the dispatching brief got wrong** (see
[[verify-deferred-issue-premises]] — briefs decay the same way deferred issues
do):
1. **No hook script references `quiz` at all** (`git grep -i quiz -- hooks/` is
   empty). The brief claimed `human-decision-gate.sh` / `reviewer-route-gate.sh`
   reference the token "in multiple places". They gate *writes to the DECISION
   path*; they never parse its grammar.
2. The brief's file list **missed 5 files**, including the two heaviest test
   surfaces (`dashboard-decision-run.test.js` 52 hits,
   `dashboard-decision-block.test.js` 40) and `decision-block.js`, where
   `QUIZ_TOKENS` is a **newline-injection guard**, not mere validation.
3. `skills/to-tickets/SKILL.md:42` ("Quiz the user") is a **false positive** —
   vendored upstream skill, unrelated sense.

**How to apply:** if this spec is re-scoped or a unit FAILs, re-read the
"speed regulator" framing before agreeing to drop the token. And re-derive the
file list by grep rather than trusting a brief's enumeration.
