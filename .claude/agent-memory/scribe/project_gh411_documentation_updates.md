---
name: gh411_documentation_updates
description: Domain model updates for core-file extraction and adapter parity test retargeting
metadata:
  type: project
---

## Documentation completed for unit #411

**Unit #411 PASSED review** at commits 9b1e768/cbd53d5 (M2 tier 2 — extract reviewer-route-gate/stop-gate cores, retarget parity tests).

**Reviewer flagged four documentation gaps** that have now been resolved:

### 1. Stale "Adapter behavioural parity" entry
- **Old scope**: described test as checking "do ports agree" in two scenarios (defer dedupe, empty-after-colon rejection)
- **New scope**: test now verifies core-file agreement + payload-shape translation per port (broader, different)
- **Updated** CONTEXT.md lines 272-292 to reflect: (1) each thin entry script translates native payload into core's contract, (2) full review-join scenario once on Claude + two-case smoke test on adapters, (3) mutation controls prove core logic is exercised

### 2. Four new load-bearing glossary terms added
**Core file** (lines 294-306): port-invariant decision logic at `hooks/scripts/lib/<name>-core.sh`, sourced by thin entry scripts, byte-identical across all three ports

**Declared-shared set** (lines 308-317): the `SHARED_HOOK_LIB_FILES` array in `bin/cli.js` listing files mirrored to both adapters (Codex, Cursor)

**Payload-shape translation** (lines 319-330): per-port work to convert native hook payload (e.g. `.agent_id` vs `.subagent_type`) into normalized form the core expects

**Thin entry script** (lines 332-341): canonical terminology replacing ambiguous "shim"; per-port hook wrapper that translates payload and sources the core; contains no decision logic itself

### Non-blocking advisory (unresolved)
Comment in `hooks/scripts/lib/stop-gate-core.sh` line 37-38 claims "every terminal decision routes through block()/allow()" but one path (markerCommitCheck mode=block mismatch) still bare-exits on codex port. Pre-existing from before gh411 (not a regression). Reviewer left this as optional documentation note — defer to future refactoring.

**Issue #411 closed** via `gh issue close` with reference to these updates.
