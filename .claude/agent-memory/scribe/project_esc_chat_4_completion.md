---
name: esc-chat-4 completion
description: esc-chat-4 (2026-10-03) landed ADR-0039 + prompt-confirmed decision write glossary; esc-chat-1 ship gate and teammate-identity premise still owed — revisit docs when operator records land
metadata:
  type: project
---

esc-chat-4 landed ADR-0039 (prompt-confirmed decision write; amends ADR-0036, narrows ADR-0034 for one shape) and seven harness-glossary terms. Two premises are written as PENDING, not fact: the esc-chat-1 Bash-ask measurement (`docs/experiments/2026-10-01-probe-bash-ask.md`, not yet run) and the teammate-has-no-agent_id premise (followups plan R4, `scripts/probe-hook-identity.sh` not yet run).

**Why:** the plan requires docs to describe landed behaviour only; claiming the measurement passed would repeat the gh377-7 class of FAIL.

**How to apply:** when either operator record is committed, update ADR-0039 "Pending measurement", the **Ship gate** and **prompt-confirmed decision write** entries, trust-model row 20 and README; then decide whether the deferred probe terms (genuine teammate, identity row, teammate check) earn glossary entries. Trust-model C2.4b greps ADRs/CONTEXT for "asked ... without ... completed ... means denied" — keep decline prose free of "completed"/"denied". See [[gh377-7]] lessons in [[feedback_verify_each_disk_sink_and_field_location]].
