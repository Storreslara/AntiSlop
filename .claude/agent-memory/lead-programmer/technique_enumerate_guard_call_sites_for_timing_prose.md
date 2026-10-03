---
name: technique-enumerate-guard-call-sites-for-timing-prose
description: Prose saying WHEN a hook guard runs must come from grepping every call site of the guard function and its hook matcher, not from the guard's purpose (esf-flag-prose FAIL)
metadata:
  type: feedback
---

Before writing "X happens on the next A or B", grep the function that does X
(e.g. `state_drop_resurrected_flags`) across `hooks/scripts/lib/*-core.sh` and
read each call site's guard conditions and its `hooks/hooks.json` matcher.

**Why:** esf-flag-prose FAILed because I wrote "next `Stop` or reviewer
dispatch". The guard in `reviewer-route-gate-core.sh` runs on EVERY `Agent`
dispatch, before the target-type match and before the `off` check. That also
made the `off` exception ("still runs at `Stop`") incomplete.

**How to apply:** for each call site, write down (event, filters that run
before the call, mode checks that run after it). Then check any neighbouring
"X blocks Y" sentence for consistency. In the esf case, a resurrected flag
never blocks the gated dispatch, because that dispatch drops it first.
