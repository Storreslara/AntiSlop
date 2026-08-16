---
name: gh405-adr0003-tbd-placeholder
description: gh405 filed ADR-0024, leaving ADR-0003's two "(ADR TBD, Step 5)" placeholders unresolved
metadata:
  type: project
---

`docs/adr/0003-hivemind-split-spec-master-task-master.md` (lines ~44, 54) has
two `**Superseded by (ADR TBD, Step 5):**` placeholders, added by the
ceremony-reduction plan's Step 3 dispatch pending Step 5 filing the real ADR
number. gh405 Dispatch B filed that ADR as
`docs/adr/0024-ceremony-reduction-solo-operator.md`, but ADR-0003's own
placeholders were **not** in gh405's affected-files list (only the new ADR,
ADR-0018's annotation, and CONTEXT.md/wiki glossary entries were), so they
were left as literal "TBD" text — flagged in `.claude/wiki/changelog.md`'s
2026-08-16 gh405 entry, not fixed.

**Why:** the dispatch contract scoped affected files precisely per-persona
per-step; ADR-0003 belonged to Step 3's dispatch (gh403), not Step 5's. A
loose end can be correctly "not my scope" even when the fix is trivial and
the information (the real ADR number) is in hand.

**How to apply:** if a future unit touches `docs/adr/0003-*.md` again, or if
asked to do a general ADR-consistency sweep, replace both `(ADR TBD, Step 5)`
instances with `0024` (or whatever supersedes it by then) — annotate in
place per this repo's inline-`**Superseded by**` convention, don't rewrite
the surrounding text. Don't do this unprompted outside an explicit dispatch
that lists `docs/adr/0003-*.md` as an affected file — the same "stay inside
the named affected-files list even when a related fix is obvious" discipline
that motivated recording this.
