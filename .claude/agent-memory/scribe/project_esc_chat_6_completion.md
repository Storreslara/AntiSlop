---
name: esc-chat-6-completion
description: esc-chat-6 docs cleanup of esc-chat-5 notes; Unicode [[:space:]] list measured wider than the prompt said; validate.sh flaked twice then passed
metadata:
  type: project
---

esc-chat-6 (2026-10-03, baseline 60b454f): ADR-0039 dialog is 8 lines not 7; stale "denied unconditionally"/"no agent can write" glossary prose reworded to the ADR-0039 invariant; Evidence-limits clause added to README, CONTEXT.md, architecture.md.

**Finding:** under C.UTF-8 `[[:space:]]` also matches U+2028 and U+2029 (besides U+1680, U+205F named in the prompt); U+00A0, U+180E, U+202F, U+0085 do not.
**Finding:** two early `tests/validate.sh` runs reported mirror-parity/cli-backfill FAILs with a clean tree; two later runs were green (rc=0). Cause not identified; likely concurrent state.
