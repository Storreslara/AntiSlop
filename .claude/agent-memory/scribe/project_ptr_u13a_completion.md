---
name: ptr-u13a-completion
description: ptr-u13a PASS 05bee1f closed #564; four open follow-ups, one (plan-scan contract_author vs inEra) blocks NR2 measurement
metadata:
  type: project
---

PASS ptr-u13a at 05bee1f, closed #564. Glossary amendments are assigned to U13b, not U13a.

Open follow-ups:
- CRLF issue body skips `Contract file:` branch (code `[ \t]*$` vs spec `\s*$`).
- Non-object persona config (null, []) fails closed in ladder-tier.sh, untested.
- agg2 t0 = first usage record with a timestamp; CHANGELOG wording broader.
- Plan-scan contracts report contract_author spec-master, which inEra excludes; gh unreachable drops every contract-file unit. Noted in the plan doc; settle before final NR2 measurement.

**Why:** carry-forward gaps from reviewer notes.
**How to apply:** check these at U13b/U13c close-out and before NR2.
