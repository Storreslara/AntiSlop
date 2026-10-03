---
name: esc-chat-4 completion
description: esc-chat-4 landed ADR-0039; esc-chat-5 (2026-10-03) replaced its PENDING premises with the two operator records (Ship gate GREEN, identity Outcome D); teammate premise still unmeasured
metadata:
  type: project
---

esc-chat-4 landed ADR-0039 (prompt-confirmed decision write; amends ADR-0036, narrows ADR-0034 for one shape) with two premises written as PENDING. esc-chat-5 (2026-10-03) updated ADR-0039, CONTEXT.md, harness glossary, trust-model row 20, README and the wiki from the committed records: `docs/experiments/2026-10-01-probe-bash-ask.md` (`Ship gate: GREEN`, a probe hook, not the real gate; CLI 2.1.287 with later banners at 2.1.288) and `docs/experiments/2026-10-03-probe-hook-identity.md` (`Outcome: D`, no genuine teammate observed, so the teammate premise is still unmeasured and `esf-eid-gate` is not triggered).

**Why:** docs may claim only what the records show (gh377-7 class of FAIL). A GREEN probe-hook run is not the real gate end to end, nor other CLI versions, nor teammates.

**How to apply:** if a genuine teammate is ever observed (re-run of `scripts/probe-hook-identity.sh` with Outcome A/B/C), revisit the "main session only" caveat in all six docs; a material CLI upgrade re-runs the Bash-ask probe (R2). On the C2.4b check in `tests/harness-integrity-gate.test.sh`: it greps ADRs, CONTEXT.md and trust-model.md for a claim that the harness-integrity gate's Set B asked/completed audit pair tells a denial from an approval. That pair is a different gate's; the decision gate's `decision-gate-asked` line has no completed partner. Write the decision-gate asked-line meaning accurately ("declined, denied (including headless), or the approved write failed"); if accurate wording ever trips C2.4b, report it as a check over-match, never reword to evade. See [[feedback_verify_each_disk_sink_and_field_location]].
