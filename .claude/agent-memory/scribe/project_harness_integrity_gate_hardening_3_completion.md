---
name: harness-integrity-gate-hardening-3-completion
description: Unit harness-integrity-gate-hardening-3 PASS completion with new gate-hardening conventions
metadata:
  type: project
---

## Unit Summary

**Unit:** `harness-integrity-gate-hardening-3` (debug-spec, 2-FAIL-cap escalation)  
**Date:** 2026-09-09  
**Status:** PASS (reviewer acceptance recorded, no tracker issue — debug-spec fast path)  
**Fix commit:** `f52bec2` (bracketed by `9cce0da` and `34e2339`)  
**Spec:** `docs/plans/2026-09-09-debug-spec-harness-integrity-gate-hardening.md`

## What was fixed

Closed a remaining bypass in the `set_a_mentioned()` glob-detection fallback of `hooks/scripts/harness-integrity-gate.sh` — specifically, **non-recursive brace-collapse** (e.g., `.claude/{persona-config,{x,y}}.json`) that evaded prior attempts' claimed closures.

## New conventions introduced

Three standing practices now codified for security gates:

1. **Family table over universal claims** — a security gate's protection docs now enumerate its known holes as a **family table** (machine-checked parity between test suite and prose) rather than asserting unbounded "detects everything" claims. Each row documents a **bypass family**, its status (closed/residual/over-block), and the reason (if applicable). Prevents the prior failure mode of one counterexample invalidating an entire universal claim.

2. **Reachability precondition for BLOCKED rows** — a BLOCKED test row is only credited as a meaningful closure once its spelling is *independently proved* to actually reach/stage/delete the protected file, not just asserted via syntax analysis. Implemented via `reach_proves()` probe functions in tests; prevents syntactic false positives from masking real gaps.

3. **Source-block extraction sentinels** — `# >>> … # <<<` sentinels mark a source block in `harness-integrity-gate.sh` that a property test extracts via `awk` and evaluates directly, so the test exercises shipped source rather than a re-implementation. Tightens the coupling between source and test.

## Glossary entries added to CONTEXT.md

Six new entries, all load-bearing in the test suite and documentation:

- **Set A / Set B** — the two disjoint protected-path categories (Set A denied on Write/Edit and Bash; Set B only on Write/Edit, per [ADR-0025](docs/adr/0025-textual-gate-protection-requires-structural-triggers.md))
- **bypass family** — a class of obfuscation techniques that could evade the gate
- **family table** — the frozen enumeration of bypass family closure status
- **documented residual** — a known, deliberate bypass family outside this unit's scope
- **accepted over-block** — a family the gate blocks even though unreachable in this project

Plus clarifications on the Set A/Set B asymmetry in **Set A / Set B** entry itself.

## Known residuals (deliberately out of scope)

Two bypass families remain **deliberately undocumented-as-fixed, documented-as-residual**:

- **`wd-relative`** — working-directory modelling (`cd`/`-C`/variable-splitting spellings). Requires shell-state tracking, a different axis from glob detection.
- **`hidden-claude-segment`** — `.c*/` prefix glob hiding the literal `.claude` substring. Relies on the Bash branch's substring match on `.claude` token.

Both are pinned as **characterization tests** (expected-ALLOWED) in the suite, not treated as failures or future TODOs.

## Advisory items flagged by reviewer

1. Stale plan-doc line (`.claude/constitution.md` asserts non-existence; file exists at v1.0.0)
2. Lead-programmer's memory note has stale variable name (`$normalized_chunk` → `$g`)
3. **Glossary gap resolved** — CONTEXT.md now holds entries for Set A, Set B, bypass family, documented residual, accepted over-block, family table
4. One residual worth recording: fixpoint brace-collapse anchors on *first* `.claude` occurrence, so `.claude-notes/x/.claude/persona*.json` anchors wrong and is ALLOWED — candidate for future `wd-relative`-adjacent spec

## Related issues and ADRs

- [ADR-0025](docs/adr/0025-textual-gate-protection-requires-structural-triggers.md) — foundational principle: textual gates trigger on path shape + program identity, never word presence alone
- Spec: `docs/plans/2026-09-09-debug-spec-harness-integrity-gate-hardening.md`
- Prior FAILs closed: `c71ed27` (attempt 1: anchoring, metachar, backslash, brace-depth-1, prefixed-path), `341ec67` (attempt 2: same plus incomplete brace-nested)
- This unit closes brace-nested via fixpoint collapse, plus all three new conventions

## Implementation details

**Affected files:**
- `hooks/scripts/harness-integrity-gate.sh` — fixpoint brace-collapse loop, source-block sentinels
- `.claude/hooks/scripts/harness-integrity-gate.sh` — mirror (byte-identical)
- `tests/harness-integrity-gate.test.sh` — expanded family-table tests with reachability probes
- `CONTEXT.md` — new glossary entries (this unit's scribe duty)

**Conventions in code:**
- Set A is detected by `set_a_mentioned()` after normalizing: chunking on metacharacters, stripping backslashes/quotes, re-anchoring at first `.claude`, collapsing braces innermost-first to fixpoint
- Test suite checks **all nine Set A literals** × **two glob spellings** × **six metachar shapes** to ensure closure
- Reachability proven by `reach_proves()` before crediting a BLOCKED row
