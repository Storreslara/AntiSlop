---
name: gh354-dispatchA-completion
description: gh354 scribe half (Step 5 of dashboard-decision-approval-surface plan) — 3 glossary entries + ADR-0030, live-rederived number
metadata:
  type: project
---

Unit gh354 (dashboard-decisions Step 5) was split into two dispatch halves
under one unit id: scribe owns `CONTEXT.md`/`docs/adr/`, lead-programmer owns
`README.md`/`docs/plans/2026-08-10-microworld-dashboard.md` (the D8 vacuity
record). Scribe half completed 2026-09-04:

- Three distinct `CONTEXT.md` entries added: **decision surface**,
  **milestone findings record**, **composed decision command** — each its
  own `**term**:` header, not one entry naming all three.
- `docs/adr/0030-decision-surface-composes-milestone-findings-write-duty.md`
  created. Number re-derived live by listing `docs/adr/` at execution time
  (0001-0006, 0008-0029 existed; 0007 deliberately absent/skipped per the
  dispatch's explicit instruction not to backfill it) — did NOT trust the
  issue text's "0021 as of 2026-08-13" guess, which had already drifted by
  9 numbers due to unrelated intervening ADRs (0022-0029) landing first.
  ADR records: compose-only for all four touchpoints (trust-anchor
  mechanics), the write duty staying with Write-less `milestone-auditor`
  via a named `Bash` bookkeeping exception (same carve-out as reviewer's
  `.pass`/`.fail`/`.escalated` markers), and the R6 decision NOT to convert
  touchpoint 2 (pre-audit checkpoint) to async.

**Why:** the issue's own text pre-warned the ADR number in its written
instructions may be stale by execution time — this played out exactly as
warned, confirming "always re-derive, never trust a spec's embedded number
guess" for this ADR-numbering class of unit.

**How to apply:** any future dashboard-decision-surface follow-up work
should link back to ADR-0030 rather than re-deriving the compose-vs-write
rationale. See [[gh332_dispatchA_completion]] for the sibling pattern (live
re-measurement over trusting spec-embedded guesses) from a prior unit in
this same docs/glossary/ADR risk class.
