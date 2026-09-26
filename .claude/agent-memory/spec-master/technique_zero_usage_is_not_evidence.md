---
name: technique-zero-usage-is-not-evidence
description: Before reading a zero-usage audit measurement as evidence a mechanism has no value, check whether the gate that would have triggered it was even armed — in warn/off mode the zero is a tautology
metadata:
  type: project
---

A "this feature has never been used in N weeks of audit history" finding is
worthless until you check **whether the thing that triggers it was armed during
those N weeks.** If the gate was in `warn`/`off` mode, nothing was blocked, so
nothing ever needed the bypass, so zero uses is what the configuration
*predicts* — not evidence about the bypass's value.

**Why:** 2026-09-26, item11-2. A reviewer independently verified zero `override=`
and zero `override-replay=` entries in `.claude/dispatch-audit.log` across
~7 weeks, and proposed deleting the `.claude/.dispatch-override` escape hatch as
demonstrably unused. Measured instead: `dispatchHygiene.mode` is **`warn`**
(flipped from `block` by commit `0f6efa7`, 2026-08-16T05:51:15Z, ADR-0024's
solo-operator posture), and `dispatch-hygiene.sh:390-396/409-410` emits `warned=`
only in warn mode while only `block` reaches `exit 2`. The log's **every** line
carries `warned=` — so the log itself proves the posture, there were **zero
blocked dispatches**, and the hatch's trigger condition never once occurred.
Worse, the log's first line (`2026-08-16T05:51:06Z`) starts 9 seconds before the
posture commit: the audit record and the warn posture begin together, and the
only block-mode window (2026-08-02 to 2026-08-16) is exactly the unrecoverable
blind gap at the front of the log with no rotation archive. The measurement was
structurally incapable of answering the question.

**How to apply:** for any zero-usage argument, establish three things before
reasoning from the zero — (1) the mechanism's **arming state** across the
measured window, read from live config, not from a default documented elsewhere;
(2) whether the log's own **event vocabulary** discloses that state (here
`warned=` vs `blocked=` did, for free); (3) whether the window covers the
mechanism's whole lifetime — compare the log's first timestamp against the
landing commits of both the feature and its host. Then ask the denominator
question: a log that records only violations has no total-dispatch denominator
at all, so its line count is never an exposure base.

**Second half, for a plugin/product repo:** this repo's own posture is not the
product's. `dispatchHygiene.mode` defaults to `block` in the hook
(`dispatch-hygiene.sh:124`) and no scaffold path writes the key, so every
freshly-installed downstream project *blocks* — where the escape hatch is the
only per-dispatch bypass and the alternative is disarming the gate globally.
Never generalize a local `warn`-posture observation into a product-wide deletion.
A sanctioned escape hatch also underwrites the shared protocol's "Blocked by a
gate you do not own" rule; deleting one leaves only unsanctioned routes.

**Two harness-glossary facts verified while checking this, both of which caused
a wrong reading:** `_Avoid_:` lines in `docs/harness-glossary.md` are
**entry-scoped, not global** (`:1533` says "for this specific" in its own text),
so `:370` deprecating "escape hatch" applies only to the human-confirmation
branch — a reviewer note claiming the hook's own `:401` message contradicted it
was a false positive. And the glossary is **not alphabetically ordered** (one
`## Language` header; entries run `:488`, `:776`, `:895`, `:2401` out of order),
so never direct an implementer to "the alphabetical position".

See [[feedback-baselines-expire]], [[feedback-no-forced-changes]],
[[feedback-reproduce-advisory-figures-at-defect-scope]].
