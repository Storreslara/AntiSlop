---
name: adr-numbering-increment-not-backfill
description: ADR numbers come from "highest on disk + 1", never from filling gaps — docs/adr/ has a 0007 hole that CONTEXT.md still links to, so backfilling it would repoint a live cross-reference.
metadata:
  type: project
---

When a spec allocates a new ADR number, derive it as **highest existing number
+ 1**, per `skills/domain-modeling/ADR-FORMAT.md` § Numbering ("Scan
`docs/adr/` for the highest existing number and increment by one"). It does not
say to fill gaps, and gaps here are **not** free slots.

**The concrete trap:** `docs/adr/` has no `0007-*.md` and never has in git
history — but `CONTEXT.md` links `[ADR 0007](docs/adr/0007-agent-identity-audit-logging-hardening.md)`.
Writing a new ADR as 0007 would silently repoint that live reference at an
unrelated document.

**Why:** ADR numbers are cited from CONTEXT.md, the wiki, other ADRs' Status
lines, and shipped plan docs. A number is a durable public identifier, so
reuse creates a false institutional record — the exact failure class the
institutional-record steps exist to prevent. Holes are cheap; collisions are not.

**How to apply:** before hardcoding an ADR path into a spec step's acceptance
criteria, run `ls docs/adr/` at authoring time **and** add a criterion that
re-derives it at execution time — a plan written days earlier can be overtaken
by a sibling spec landing the same number. That is not hypothetical: spec #245
landed `0012-vendored-skill-declared-deviations.md` while spec #229's Step 15
still hardcoded `0012`, making its `ls docs/adr/0012-*.md` criterion vacuous
(it matched the *other* spec's ADR). Pair the number check with a collision
guard asserting the neighbouring ADR is byte-unchanged. See
[[reviewed-path-gate-blocks-bash]] for how to inspect review markers when
cross-checking which units already landed.
