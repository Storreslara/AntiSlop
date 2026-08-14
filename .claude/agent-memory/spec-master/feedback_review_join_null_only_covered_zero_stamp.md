---
name: review-join-null-only-covered-zero-stamp
description: A risk/mitigation sentence in a plan ("emit null rather than guess") is not itself an acceptance criterion — verify the shipped criterion actually covers every case the sentence claims
metadata:
  type: feedback
---

When a Risk (R8 of [[project_dashboard_decision_surface_spec]]) states a
mitigation is "already specified" elsewhere in the same document, that
cross-reference is a claim, not a fact — check the referenced acceptance
criterion actually covers the case the risk names, not just the case it was
easiest to write a test for.

**What happened:** R8 named the invariant-broken case explicitly (concurrent
gated dispatches leave >1 `.review-join.<unit-id>` stamp standing) and
claimed "the mitigation is already specified: emit `unit: null` rather than
guess." Step 1 case (d) as written and shipped only asserted the
*zero-stamp* null path (no stamp at all → null). The *multi-stamp* path was
never asserted, so the shipped code's "pick the newest, unconditionally"
implementation matched the letter of case (d) while silently mislabeling
every ambiguous entry — found live in the repo by the reviewer the same
session two units happened to be mid-review concurrently
(`.claude/reviewed/gh350.pass` non-blocking note 1).

**Why:** a risk section naming a scenario and a Step's acceptance criteria
actually testing that scenario are two different artifacts. Writing the risk
does not make the criterion true; only reading the criterion's own fixture
does. This is the same class of gap as
[[feedback_goal_prose_vs_step_table_drift]] (Goal prose vs. step table) but
one level more specific: here the *Risk* prose and the *Step's own named
case letter* (d) disagreed, inside the same document, about what "the null
path" covers.

**How to apply:** when a Risk/R-item says "already specified" or "already
covered", don't take it on faith even within your own just-finalized spec —
grep the referenced step's fixture/test cases for the *specific* scenario
named (here: does the test construct >1 live stamp, or only 0 and 1?), not
just the general shape of the assertion (here: does the test assert
`unit === null` at all — yes, but for the wrong reason). The fix spec is
`docs/plans/2026-08-14-decision-join-ambiguity-fix.md` — one function
(`joinPendingReviewUnit` in `bin/microworld-dashboard/decisions.js`), fast
path, 1 unit: return `null` for both 0 and >1 live stamps instead of always
returning the newest.
