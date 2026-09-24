---
name: unit479_cost_governance_step3_protocol_prose_gaps
description: Unit #479 (cost-governance-step3-protocol-prose) known gaps and non-blocking items
metadata:
  type: project
---

**Unit:** cost-governance-step3-protocol-prose, issue #479

**Status:** PASS (2026-09-24). Final commit: bd9e0ad. Version: 0.31.79

## Non-blocking gap: Templates/persona-protocol-slim.md drift not mechanically guarded

The new protocol paragraph on Bash-output spill-to-file is duplicated across four hand-maintained sources:
- `personas/scribe.md`
- `personas/reviewer.md`
- `templates/codex-protocol.md`
- `templates/cursor-protocol.md`
- And 12 regenerated mirrors in adapter ports

However, the third hand-maintained source, `templates/persona-protocol-slim.md`, lacks an equivalent test guard. The reviewer proved by mutation that **deleting the new paragraph from the slim template silently passes `tests/validate.sh`** — drift is only caught opaquely via an unrelated cli-backfill mirror-mismatch failure in the broader test suite, not directly.

**Effect:** Future edits to the slim template could diverge from the canonical protocol without surfacing as a direct validation failure. Changes to the protocol paragraph would need coordinated updates across all five hand-maintained files, but only four are mechanically guarded.

**Guard surface:** `tests/adapter-protocol-parity.test.js` contains literal probes for the new paragraph guarding codex and cursor ports, but no equivalent assertion covers the slim template.

**Out of scope:** Adding a mechanical guard for the slim template is a test-suite hardening item, not required for this protocol-prose landing. The content-correctness is verified by reviewer inspection; the drift-detection gap is a maintenance item for future test-enhancement work.

**Recording:** This doc serves as a known-gaps reference for future test-coverage expansion on hand-maintained protocol sources.

## Cross-unit process issue: Concurrent fileHashes regeneration blocks via gate

Both this unit (cost-governance-step3-protocol-prose) and its sibling unit (cost-governance-step4-effort-tiers) shipped without `.claude/persona-config.json` fileHashes regeneration in their own commits. Root cause:

`harness-integrity-gate.sh` blocks any Bash command text that names the `.claude/persona-config.json` path directly, forcing `git add -A` on a clean tree as the only staging route. When a concurrent sibling unit has a dirty tree, `git add -A` fails the precondition gate.

**Effect:** Distributed units that require fileHashes regeneration either:
1. Ship without their own fileHashes updates (deferred to a follow-up bulk refresh), or
2. Block each other's concurrent completion when gate-directed path-free staging routes don't exist for this particular file.

**Workaround taken:** Both units shipped and a sibling unit (`eba2c2a`, landing two commits later) performed the consolidated fileHashes backfill for both units at once, documented on each unit's PASS marker under "cross-unit discharge."

**Out of scope:** This is a gate-design and automation issue, not a code or documentation fix. Resolution candidates for future work:
- A pre-commit guard running `tests/filehashes-currency.test.js` as a mechanical backstop
- A gate-sanctioned path-free staging route specifically for `.claude/persona-config.json`
- A bulk fileHashes refresh step in the release/merge checklist

**Recording:** This doc serves as a process-issue reference for future gate-hardening or CI/CD workflow improvements related to concurrent persona-config updates.
