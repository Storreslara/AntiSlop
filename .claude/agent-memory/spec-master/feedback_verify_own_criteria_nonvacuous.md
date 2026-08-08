---
name: feedback-verify-own-criteria-nonvacuous
description: Before finalizing a spec, RUN each acceptance criterion against the current tree — a criterion that already passes (or trivially passes) is vacuous and gates nothing
metadata:
  type: feedback
---

Run every acceptance criterion I author against the working tree *before*
handing the spec off, and confirm it is currently RED. A criterion that is
already green, or that greps for a string no target file contains, gates
nothing and will be reported as satisfied without the work being done.

**Why:** on the 2026-08-07 commit-anchored-markers spec I wrote
`! grep -rq '<old printf>' hooks/scripts/ commands/ skills/` as a "the old
format is gone" check across four files. Running it revealed the pattern
matched only ONE of the four: one file wraps the same printf across two lines
(so a single-line grep misses it) and another spells a different variant. Three
of the four files could have been left completely un-updated and the criterion
would still have passed. Caught only by executing it, exactly the failure
constitution P1 ("Verify, don't assume") names. Same shape as
lead-programmer's own `feedback_grep_acceptance_line_wrap` memory — but I am the
one who AUTHORS criteria, so the check belongs on my side first.

**How to apply:** prefer one criterion per file over one recursive grep across
a directory. For each, run both halves — the negative (`! grep old`) and the
positive (`grep new`) — and assert the positive currently returns 0 matches.
Multi-line/wrapped source strings are the specific trap: grep is line-oriented,
prose files wrap, so never grep a token longer than a plausible line.
See [[feedback-no-forced-changes]] and [[feedback-baselines-expire]].
