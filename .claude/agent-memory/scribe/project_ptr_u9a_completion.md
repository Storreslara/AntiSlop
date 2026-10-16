---
name: ptr-u9a-completion
description: ptr-u9a (#559) PASS 018f95e closed; ladder-tier.sh and escalation-card.sh landed; open follow-ups and a term collision
metadata:
  type: project
---

PASS ptr-u9a 2026-10-16, commit 018f95e, closed #559. Glossary: `census` added to docs/harness-glossary.md; one disambiguating sentence added under CONTEXT.md `escalation card`.

**Collision:** CONTEXT.md `escalation card` (six-line top of an `.escalated` marker) is a different thing from `bin/escalation-card.sh` (FAIL history at the 2-FAIL cap). Nothing renamed; ptr-u9b prose should keep them apart.

**Open follow-ups (not fixed):**
- bin/ladder-tier.sh:63 `jq '.defaultImplementerModel // empty'` treats present ""/null/false as absent (haiku); orchestrator.md:~484-487 and the header say opus. Fix: `has("defaultImplementerModel")`.
- bin/ladder-tier.sh:118 ignores contract-guard exit code (no effect today).
- Untested: --contract with missing file, invalid unit id, missing cutover line, missing jq, escalation-card with no id.
- bin/ladder-tier.sh:~101-103 skips a FAIL header with missing/malformed timestamp instead of treating it as pre-cutover (leans cheaper; all real records well-formed).
- AC9.2 (census = raw count, single-unit mode applies expiry) is a task-master ruling spec-master may overturn.
- Plan Step U9 lists tests/fixtures/ladder-tier/** but contract used temp-dir fixtures; tests depend on live .fail records and git history (shallow clone fails).

**Why:** reviewer NOTEs on the PASS marker. **How to apply:** check these before building on ladder-tier.sh or touching ptr-u9b prose.
