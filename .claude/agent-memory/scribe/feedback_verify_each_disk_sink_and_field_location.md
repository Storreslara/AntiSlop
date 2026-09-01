---
name: verify-each-disk-sink-and-field-location
description: When documenting a write-side effect in CONTEXT.md, verify every claimed disk sink and every claimed field/line location against actual code — don't generalize from one confirmed write.
metadata:
  type: feedback
---

Reviewer FAILed gh377-7 Dispatch A (scribe half, commit `1dc88f7`) on 4 defects,
all in the same family: CONTEXT.md prose that got the *shape* of a write right
but the *details* wrong.

- Claimed "writes exactly one file" when the dashboard decision-confirm path
  actually hits two disk sinks: the DECISION file (`server.js:507`) AND an
  `fs.appendFileSync` to the review audit log (`server.js:533`).
- Claimed a `via:` annotation lives "in the audit-log line" when it's actually
  written into the DECISION file body (`decision-block.js:126`); the audit log
  gets its own separate line with a different, distinct format
  (`decision-write-via-dashboard task=… route=… by=…`) that contains no `via:`
  token at all.
- Fabricated that `via: terminal` is emitted for the terminal/copy path — `git
  grep -n "via: terminal" -- bin/ hooks/` returns nothing; it's only an unused
  allowlist entry in `VIA_ROUTES` (`decision-block.js:21`). The real state is
  binary: absent (hand-typed or copy/heredoc path) or `via: dashboard`
  (confirmed dashboard write only).
- ADR-0027 cited "ADR-0003 (fast-path dispatch threshold)" as a related
  decision — ADR-0003 is actually about splitting `hivemind` into
  `spec-master`/`task-master`, unrelated. Filler "unrelated; included here for
  completeness" framing compounded it (content-free, should never have shipped).

**Why:** each of these came from writing plausible-sounding summary prose
("writes exactly one file", "via: audit-log annotation") without grepping the
actual write sites and actual emitted strings for every distinct claim in the
sentence — one confirmed fact (a write happens; via: exists) got generalized
into adjacent, unverified claims (only one write; via: lives in the audit log;
via: terminal is also emitted).

**How to apply:** when writing or reviewing a CONTEXT.md sentence that
describes what a code path writes, treat every noun phrase as a separate
checkable claim: grep for `writeFileSync`/`appendFileSync` (or the analogous
sink) to enumerate ALL sinks, not just the first one found; confirm which file
each token/field actually lands in, not just that it exists somewhere; and for
any "always/never" claim about a variant not being emitted, grep for the exact
string before asserting it. Related ADR cross-references need the same
treatment — verify the target ADR's actual title/subject, don't rely on the
number alone.

See [[gh413_state_model_documentation]] for the broader pattern of scribe
glossary-entry dispatches on this state/dashboard subsystem.
