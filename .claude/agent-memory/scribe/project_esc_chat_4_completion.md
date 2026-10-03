---
name: esc-chat-4 completion
description: ADR-0039 premises after esc-chat-5 (2026-10-03) — Bash-ask record exists but review FAILed it (Display rows unsupported), so full-heredoc premise still pending; identity record Outcome D, teammate premise unmeasured
metadata:
  type: project
---

esc-chat-4 landed ADR-0039 (prompt-confirmed decision write; amends ADR-0036, narrows ADR-0034 for one shape) with two premises written as PENDING. esc-chat-5 (2026-10-03) cited the two operator records. `docs/experiments/2026-10-03-probe-hook-identity.md` reads `Outcome: D` (no genuine teammate observed; `esf-eid-gate` not triggered; teammate premise still unmeasured). `docs/experiments/2026-10-01-probe-bash-ask.md` was script-graded `Ship gate: GREEN`, but review (unit esc-chat-1-record) FAILed it mid-unit: its Display rows have no support in its own appendix (panes saved after the decline), and the run spanned CLI 2.1.287 and 2.1.288. esc-chat-5's first pass called the premise "measured" and had to be revised back to "pending a re-measurement".

**Why:** a dispatch saying a record is "committed and verified" is a dated claim; a script-graded GREEN is not evidence unless the record's own appendix backs each row. Same lesson as [[feedback_verify_plan_premise_freshness]].

**How to apply:** before flipping any "pending" to "measured", check that the record's appendix itself shows what each row claims, and check for a reviewer verdict on the record commit. When the fixed-script re-run lands, revisit ADR-0039, CONTEXT.md, harness glossary (Ship gate), trust-model row 20, README and `architecture.md`. On C2.4b in `tests/harness-integrity-gate.test.sh`: it greps for claims that the harness-integrity gate's Set B asked/completed pair tells denial from approval, a different gate's pair. Write the decision gate's asked-line meaning accurately ("declined, denied (including headless), or the approved write failed"); if accurate wording ever trips C2.4b, report the over-match, never reword to evade. See [[feedback_verify_each_disk_sink_and_field_location]].
