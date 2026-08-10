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
