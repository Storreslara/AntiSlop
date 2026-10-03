---
name: esc-chat-4 completion
description: ADR-0039 premises after esc-chat-5 (2026-10-03) — Bash-ask re-run 229138e passed review (GREEN, 2.1.288 only, probe hook); first record cbb918e failed and is superseded; identity Outcome D, teammate premise unmeasured
metadata:
  type: project
---

esc-chat-4 landed ADR-0039 (prompt-confirmed decision write) with two premises PENDING. esc-chat-5 (2026-10-03) went through three passes: (1) flipped to "measured" from record cbb918e; (2) reverted to "pending" when review FAILed cbb918e (no dialog text in its appendix; run spanned 2.1.287/2.1.288); (3) flipped to measured again after the fixed script (253106e) re-run, record 229138e, passed review. Final state: measured on claude 2.1.288 only, default/acceptEdits/auto, probe hook (not the real gate), full heredoc in the dialog block, decline creates no file (filesystem check, corroborated off-record), headless denied. Not measured: real gate end to end, other versions, teammates. Identity record: `Outcome: D`, `esf-eid-gate` not triggered.

**Why:** a dispatch saying a record is "verified" is a dated claim; a script-graded GREEN is not evidence unless the record's own appendix backs each row and review has passed the record commit. Same lesson as [[feedback_verify_plan_premise_freshness]].

**How to apply:** before flipping "pending" to "measured", check the record's appendix shows each row's evidence and that a reviewer PASS exists for the record commit. A material CLI upgrade re-runs the probe (R2); a genuine-teammate observation (Outcome A/B/C) reopens the "main session only" caveat. On C2.4b in `tests/harness-integrity-gate.test.sh`: it targets the harness-integrity gate's Set B asked/completed pair, a different gate's; write the decision gate's asked-line meaning accurately ("declined, denied (including headless), or the approved write failed") and report any over-match rather than rewording. See [[feedback_verify_each_disk_sink_and_field_location]].
