---
name: rgh-u1-1-reviewer-advisory-notes
description: Reviewer advisory notes on audit file 2026-10-06-adr0026-forward-rule.md (unit rgh-u1-1, PASS 2026-10-06, issue #505 closed)
metadata:
  type: project
---

## Population composition not disclosed in audit file

The 205-unit population includes non-sonnet implementer tiers (era-inferred breakdown from snapshot):
- 158 sonnet
- 2 sonnet+sonnet  
- 22 opus
- 3 fable
- 3 haiku
- 17 mixed sonnet/opus

Additionally, 151 units with `terminal_ts` before 2026-08-25 are excluded by design, but the audit file does not state this in prose. The contract fixes the formula, so this is not a defect — the human spirit ruling should understand this composition.

## Letter-verdict ambiguity

`letter-verdict: met` covers only the rate half of the ADR rule; the spend half is unverifiable and spirit is PENDING-HUMAN (which the file states correctly). Margin: 30.7% vs 32.5% on era-boundary, mtime-vs-content-timestamp bases (63/205 vs 66/203 units), a small margin but no over-claiming prose exists.

## Contract baseline drift

The spend-accounting-rate reproduce line uses `--until=2026-10-06T00:00:00Z`. Live output today gives 31.4% (423 units), matching the file. The contract baseline said 424 units at a later cutoff — harmless drift.

## Possible future glossary entries

- `letter-verdict` — rate-only verdict label (not comprehensive rule assessment)
- `spirit-ruling` — human judgment phase pending
