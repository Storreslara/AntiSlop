---
name: amendment-criterion-spans-two-units
description: When a spec amendment adds a criterion to unit A that asserts over an artifact unit B authors, flag B's stale body upward — never silently edit B or move the work
metadata:
  type: feedback
---

A spec amendment can add an acceptance criterion to one unit that asserts
over an artifact a **different** unit authors (gh473's C4.9 asserts content
in the ADR that gh472's scribe writes). The criterion lands on the verifying
unit, but the *authoring instruction* has nowhere to go if the other unit's
issue body is out of scope for the edit.

Do three things, in this order:

1. Put the criterion on the verifying unit as instructed — it is legitimate
   there, since the authoring unit blocks it and the artifact exists by
   dispatch time.
2. Add a **conditional hand-off** section to the verifying unit: read the
   artifact, check the criterion, and if it fails **stop and report**
   rather than editing another persona's write scope. Include the exact
   text the remedy should add, so the follow-up dispatch is mechanical.
   (Distinct from [[split-unit-across-persona-scopes]], which is for a unit
   that *authors* across two scopes; this one only *verifies*.)
3. **Report the other unit's stale body upward, loudly.** Do not edit it
   when the caller scoped you to one issue — but never leave it unsaid
   either. Same for any instruction in the other unit that the amendment
   silently contradicts (gh472 still directed a `CONTEXT.md:322` amendment
   the amendment had just withdrawn).

**Why:** the amendment is internally consistent in the spec and inconsistent
on the tracker. Whoever dispatches the authoring unit reads only its issue,
so an unflagged contradiction ships as real work that the verifying unit
then fails on — a FAIL manufactured by the fix.

**How to apply:** any narrow "update issue N to match the amended spec"
follow-up where the amendment's new criteria mention files owned by a
sibling unit. Check the sibling's body read-only before you finish.
