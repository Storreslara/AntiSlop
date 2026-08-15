---
name: heavy-trigger-not-in-protocol
description: The heavy-unit trigger lives only in ADR-0004 (amended by ADR-0013), NOT in templates/persona-protocol.md — the 2026-07-28 microworlds plan asserts otherwise and ships an unsatisfiable grep criterion.
metadata:
  type: project
---

The heavy-unit trigger (≥~8 impacted files OR ≥~400 changed lines;
structural/cross-cutting; security-sensitive) is defined **only** in
`docs/adr/0004-reviewer-roast-work-dual-model-routing.md` § "Heavy unit
trigger", amended by ADR-0013 (which removed the separate fable dispatch it
originally gated). Measured 2026-08-10:
`grep -rn 'impacted files' agents/ templates/ adapters/` returns **nothing**.

`docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md` Step 4
(issue #133) states the trigger is "already defined in this protocol's
'Reviewer roast-work advisory pass trigger' section" and carries the
acceptance criterion ``grep -c '≥ ~8 impacted files'
templates/persona-protocol.md`` is 1. **Both the premise and the criterion are
false** — no such section exists and the count is 0, so the unit would FAIL on
a criterion no implementation can satisfy.

**Why:** the trigger was concretized into ADRs and persona files over several
rounds (see `docs/plans/2026-07-17-heavy-trigger-fail-check-wording.md`), and
the 2026-07-28 plan assumed it had also landed in the shared protocol. It never
did.

**How to apply:** when a spec references the heavy-unit trigger, point at
ADR-0004 and assert the pair `grep -c 'impacted files' <target>` is **0**
(not duplicated) plus a grep for the ADR filename (referenced) — never grep a
threshold string against `templates/persona-protocol.md`. Correct #133's
criterion before dispatching it. Related: [[verify-own-criteria-nonvacuous]],
[[verify-deferred-issue-premises]].

**Update 2026-08-15 (milestone-audit round, Steps 12–15 of the same plan).**
Three things now settled, all re-measured:

1. **The correct pair was already on the record and I did not need to invent
   it.** `.claude/reviewed/gh133.pass` line 1 shows the gh133 reviewer
   silently substituted the right check at review time and recorded it:
   `grep -c "impacted files" templates/persona-protocol.md (0); grep -q
   0004-reviewer-roast-work-dual-model-routing templates/persona-protocol.md`.
   **Always read the `.pass` marker of the unit whose criterion you are
   correcting** — a reviewer who worked around a broken criterion usually
   wrote the working version down in `criteria:`.
2. **Step 4's defect is TWO occurrences, not one.** `grep -c 'impacted files'`
   over the Step 4 region returns 2: the dead criterion *and* the prose above
   it, which restates all three criteria inline and attributes them to a
   never-existent protocol section — contradicting its own next sentence.
   Also the criterion greps `≥ ~8` (spaced) while the ADR's bytes are `≥~8`
   (unspaced), so it never matched anything anywhere.
3. **The trigger under-fired twice and it is now measured.** gh137 = 18 files
   / 116 lines, gh299 = 24 files / 328 lines (its own review range
   `a251c6f..77e1211`), both PASSed with no `human:` attestation and no
   mention of the trigger anywhere in their markers. gh300 (30f/472L) did
   escalate. **But** `gh133.pass` note N4 is a reviewer explicitly reasoning
   about the trigger, concluding it met it, and returning PASS anyway for a
   correct reason (Steps 5/6/7 unbuilt, an `.escalated` marker would have been
   inert and would have stranded the session). So the defect is *invisible*
   non-escalation, not non-escalation itself — design for a **recorded
   override**, never a forced escalation.
