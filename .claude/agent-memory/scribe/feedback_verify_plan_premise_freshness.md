---
name: verify-plan-premise-freshness
description: A plan's stated invariant is a claim about the date it was drafted, not about today — re-measure it against HEAD before minting it into CONTEXT.md or an ADR
metadata:
  type: feedback
---

Before writing a plan's stated invariant into `CONTEXT.md` or an ADR, re-measure
it against the current tree. A plan doc's premise is dated evidence, not a
standing fact.

**Why:** gh354 FAILed because the source plan
(`docs/plans/2026-08-13-dashboard-decision-approval-surface.md:26`, R1 at
`:353-356`) asserted the dashboard was compose-only with "no endpoint that
accepts a decision". That was true on 2026-08-13 and was overtaken two days
later by gh380 (commit `19a0cd0`, 2026-08-15), which shipped
`POST /api/decision/arm` and `/run`. I copied the premise into the canonical
glossary as an exception-free invariant plus an ADR "standing regression
criterion" that was already red — its own grep returned 6 hits, not 0. Because
`CONTEXT.md` is canonical, a false claim there propagates to every citing doc,
and this one was security-relevant (it misnamed the DECISION file's trust
anchor).

**How to apply:** when a dispatch hands you an invariant to record —
especially a negative one ("never writes", "no endpoint", "zero hits") —
do three things before writing it:

1. Run the assertion as a command *now*. A regression criterion you cannot
   watch go green-to-red at authoring time is worthless; if it is already red,
   say so instead of asserting it.
2. Compare the plan's draft date against `git log` for the files it describes
   (`git log -S "<symbol>" -- <path>`). A premise older than the code is
   suspect.
3. Grep `CONTEXT.md` for terms adjacent to the one you are adding. In gh354 the
   file *already* held accurate entries — **confirmation code** (`:1683`),
   **dashboard-originated decision write** (`:1869`), **read-only mode**
   (`:1904`) — that flatly contradicted the entry I was writing. A new entry
   that contradicts a sibling entry is the cheapest possible self-check, and I
   skipped it. Cross-link instead of minting a duplicate.

Corollary: do not generalize one module's verified property to its whole
directory. `decision-block.js` really is a pure formatter; "the dashboard never
writes" was the overgeneralization that failed. Scope the claim to the thing
actually measured.

See [[gh354-fail-fix-completion]].
