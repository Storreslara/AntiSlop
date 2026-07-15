# ADR 0003: Split `hivemind` persona into `spec-master` + `task-master`

Date: 2026-07-15
Status: Accepted (completed plan 2026-07-14-threefold-update Track 3)

## Context
The original `hivemind` persona combined two distinct responsibilities: spec authoring (grilling, clarifications, constitution check, publishing via `to-spec`) and dispatch-task authoring (slicing specs into grabbable units via `to-issues`, per-unit model routing, detailed prompt crafting for `lead-programmer` and `scribe`). These are sequential but orthogonal — spec-master finalizes a spec, then task-master reads that finalized spec and never questions it.

Combining them created friction:
- **Semantic mismatch:** task-master could theoretically revise the spec mid-flight, but shouldn't — the boundary needed explicit enforcement.
- **Model eligibility:** spec-master benefits from fable (grilling is well-scoped, mechanical, low-judgment) when rules are clear; task-master does not (dispatch instruction writing is judgment-heavy). One frontmatter couldn't express both correctly.
- **Re-plan ownership:** after a reviewer FAIL, it's ambiguous whether task-master should revise the dispatch or whether a spec gap exists (requiring spec-master to fix the underlying spec). The orchestrator's dispatch routing must route FAILS correctly.

## Decision
Split `hivemind` into two personas with clear handoff:

1. **`spec-master`** (model: opus, memory: project)
   - Owns spec authoring: grilling via `grill-me`, taxonomy scorecard, Clarifications, `.fail` check, Constitution check
   - Carries every v0.9.0 worked fenced-code example verbatim (empirically required for fable/opus compliance)
   - On 2-FAIL cap escalation: produces a debug spec (diagnosis of the plan using the latest `.fail` record plus git log/git diff over fix-attempt commits, revised steps)
   - Publishes via `to-spec` skill (existing mattpocock skill, wired as `<MATTPOCOCK:to-spec>` slot)
   - Does NOT carry `<MATTPOCOCK:to-issues>` — task-master owns slicing outright

2. **`task-master`** (model: sonnet, fable excluded)
   - Reads a finalized, non-ambiguous spec — never grills, never revises the spec's substance
   - Owns `to-issues` / `to-tickets` slicing outright: one decision/one unit per ticket sizing
   - Tags each unit with a `Suggested model` per-unit tag (haiku/sonnet/opus for lead-programmer)
   - States the retrieval contract (where to fetch the spec from)
   - Writes detailed per-unit dispatch prompts for `lead-programmer` and `scribe`
   - On mid-flight spec gap discovery: signals upward to spec-master (via orchestrator), never fills the gap itself
   - Is never a re-plan owner (FAIL routing stays to lead-programmer; only 2-FAIL cap escalates to spec-master)

## Consequences
- **Clearer handoff:** spec-master → finalized spec artifact → task-master → per-unit dispatch tickets. The orchestrator's two-stage routing is explicit and mechanical.
- **Correct model eligibility:** spec-master defaults to opus (judgment-heavy grilling + debug-spec diagnosis), with fable eligible only for light, well-scoped cases. task-master defaults to sonnet, fable excluded (dispatch instruction writing is not a "light" task).
- **Deterministic FAIL routing:** normal reviewer FAIL routes to lead-programmer (unchanged); 2-FAIL cap routes to spec-master's debug spec (new), then task-master re-derives instructions. task-master never owns re-plan, eliminating the ambiguous case.
- **Spec-gap signaling:** task-master can signal a discovered ambiguity back to spec-master without silently filling it, keeping spec ownership with the right persona.
- **Migration path:** existing `hivemind` selection expands to BOTH new personas (`'hivemind': ['spec-master', 'task-master']` in `LEGACY_PERSONA_MAP`), so existing adapted projects get both when they `--update`. Adapter ports (cursor/codex) lag this release (filed as tracked follow-up).

## Related decisions
- **OQ5a (final):** `to-issues` slicing is task-master's sole responsibility — spec-master does NOT carry the `to-issues` slot. Distinct and non-overlapping from `to-spec`'s single-spec publish.
- **OQ3/OQ4 (final):** 2-FAIL cap routes to spec-master's debug spec (diagnosed from the latest `.fail` record plus git history of fix-attempt commits) plus task-master re-derives dispatch. No new mattpocock diagnostic skill added (spec-master already has Read/Grep/Bash; diagnosis is prose reasoning, not code repro).
