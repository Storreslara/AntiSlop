---
name: grep-for-the-deliverable-before-speccing-it
description: Before speccing "mechanize X" / "add a check for X", grep for whether X already shipped — and separately check whether anything INVOKES it, because a shipped detector can satisfy every acceptance criterion while the step's goal stays unmet
metadata:
  type: feedback
---

Two distinct checks before writing a "build a check for X" step, in this order:

1. **Does the deliverable already exist?** Grep `CHANGELOG.md`,
   `hooks/scripts/`, and `tests/` for X before authoring the step. A batch of
   specs authored on one date can easily post-date the thing it specs.
2. **Does anything invoke it?** This is the half that gets missed. A shipped
   script can meet every acceptance criterion a step would have written and
   still leave the step's *goal* unmet, because "a check exists" and "a check
   runs" are different properties and no criterion measures the second one.

**Why:** measured on item17-2 (2026-09-26). Step 2 specced "mechanize P3's
version-stamp check." `hooks/scripts/version-stamp-check.sh` +
`tests/version-stamp-check.test.sh` had shipped three days *before* the plan
was authored, and met six of Step 2's seven criteria — including mutation
proof in both directions, which it exceeded (5 mutation controls plus a
`mutate()` guard that aborts on a `sed` matching nothing). But
`grep -c 'version-stamp'` returned **0** across `agents/reviewer.md`,
`agents/lead-programmer.md`, `templates/persona-protocol.md` and both
`.claude/agents/` mirrors: the script's header calls itself "REVIEWER-INVOKED"
and `docs/trust-model.md` classifies it `self-reported`, yet **no persona was
ever told to run it.** `tests/validate.sh` registers the test *suite*, not the
check — the merge gate proves the detector works on a throwaway fixture repo
and never runs it against real history. A real violation landed 3 days after
the script shipped (`a9c1040`, `templates/persona-protocol.md` under an
unchanged version).

**How to apply:** when a step's goal is "caught before review rather than by a
FAIL", write a criterion for the *invocation*, not just the detector — e.g.
`grep -c '<script>.sh' agents/<persona>.md` ≥ 1, plus a criterion the unit's
own commit must satisfy using the check it installs. And when auditing an
allegedly-redundant step, report it as three-valued: criteria met / criteria
unmet / goal unmet-for-an-unmeasured-reason. "Satisfied" and "still needed"
were both false statements here.

Corollary measured in the same pass, reusable for any "which files does this
rule cover" question: **enumerate the shipped set, don't trust the glob.** P3
and the script cover `templates/*`; two of the six files under `templates/`
cannot go stale at all — `persona-config.schema.json` is named only in
`bin/cli.js` comments and never copied out (absent from `.claude/` and from
`fileHashes`), and `settings-fragment.json` is never reached by `--update`.
Two of three `violation` reports in the measured window were that schema file
alone, i.e. rule over-breadth, not distribution failure. `CONTEXT.md`'s
**version-stamped file** vs **version-stamped path** split already encoded the
distinction before any measurement did.

Related: [[verify-deferred-issue-premises]] (premises decay over time),
[[verify-own-criteria-nonvacuous]] (a criterion can pass vacuously —
this is its mirror image: a criterion can pass while the goal fails).
