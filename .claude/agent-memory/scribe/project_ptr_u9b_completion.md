---
name: ptr-u9b-completion
description: ptr-u9b PASS 5e2444e closed #560; orchestrator routing section moved to bin/ladder-tier.sh; six OPEN follow-ups, four are behaviour narrowings
metadata:
  type: project
---

PASS 2026-10-16, commit 5e2444e, closed #560. Orchestrator "Per-unit model routing" 6,226 -> 2,392 B; ladder arithmetic now in the `bin/ladder-tier.sh` header. Glossary: added "ladder-tier reason word" to docs/harness-glossary.md. CONTEXT.md ladder entries (Escalation ladder, ladder exhaustion, guard demotion, Haiku-default cutover) checked: pointers still true, untouched.

OPEN follow-ups (not fixed). Behaviour narrowings in the orchestrator move:
1. agents/orchestrator.md ~469 "On EXHAUSTED, dispatch nothing" lost the human-chosen (a)/(b) re-dispatch exception (survives only in the cap section). Add "except a human-chosen (a)/(b) re-dispatch".
2. "never a fix contract" cut to "(the contract of record)"; `--contract` on a fix-contract re-dispatch could move a demoted unit back to haiku. Say "the contract of record, never a fix contract" (~466-467).
3. Missing `--contract` was a guard demotion with user line + RULING entry; now reason=no-contract with no notice or ledger line. Treat no-contract like guard-demotion in prose (~107).
4. bin/ladder-tier.sh ~69 `// empty` treats present empty/null/false defaultImplementerModel as absent (haiku); prose says non-enum resolves to opus. Same as ptr-u9a note; fix with jq `has()`.
Other:
5. commands/start-feature-team.md ~49 `**Escalation ladder**` reference untested; could name the script.
6. Implementer ran no mutation proofs (reviewer did).

**Why:** reviewer NOTE[spec]/[code] lines on the PASS marker. **How to apply:** raise 1-4 before relying on the orchestrator prose for cap-option re-dispatch or missing-contract cases. See [[project_ptr_u9a_completion]].
