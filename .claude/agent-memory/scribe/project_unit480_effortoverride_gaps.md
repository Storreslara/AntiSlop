---
name: unit480_effortoverride_gaps
description: Unit #480 (cost-governance-step4-effort-tiers) known gaps and non-blocking items
metadata:
  type: project
---

**Unit:** cost-governance-step4-effort-tiers, issue #480

**Status:** PASS (2026-09-24). Final commits: 9109f35 + eba2c2a. Version: 0.31.79

## Non-blocking gap 1: Frontmatter check only matches column-0 `effort:` key

In `tests/effort-tier-consistency.test.js`, the frontmatter regex used to detect `effort:` declarations only matches at column 0: `^effort:`. This means an `effort:` key that is mistakenly indented — for example, placed under an `experimental:` block like the `cacheTtl` keys — will be silently dropped by the schema validator and never caught by this test.

**Effect:** A misconfiguration where `effort:` is nested under `experimental:` (parallel to how `cacheTtl` sits there in `task-master` and `reviewer`) would silently fail to declare the persona's effort level, leaving the persona to inherit ambient session effort. The test would pass but the frontmatter would have no effect.

**Precedent:** This is the same silent-drop failure mode that occurred with the `cacheTtl` validation in unit #477 (also only caught at column 0).

**Out of scope:** This gap is a test-robustness maintenance item for future guard-hardening work. Documentation of unit #480's known limitations only. No fix required in this dispatch.

**Recording:** This doc serves as a known-gaps reference for future test-suite maintenance.

## Non-blocking gap 2: No assertion that `effort:` is absent from non-tiered personas

The test `tests/effort-tier-consistency.test.js` positively asserts that `milestone-auditor` and its mirror `.claude/agents/milestone-auditor.md` both lack an `effort:` key (deliberate per 2026-09-23 user decision). However, there is no assertion that `effort:` is absent from other personas that are neither explicitly tiered nor the deliberately-absent `milestone-auditor` — for example, `lead-programmer.md`, `spec-master.md`, `orchestrator.md`, and `researcher.md`.

**Effect:** A future accidental `effort:` addition to any of these non-tiered personas (e.g., a copy-paste error during refactoring, or a misguided performance tuning attempt) would not be caught by the test suite, and could alter those personas' effort levels without the change being reviewed or documented.

**Out of scope:** This gap is a completeness-checking maintenance item for future test-suite enhancement. Documentation of unit #480's known limitations only. No fix required in this dispatch.

**Recording:** This doc serves as a known-gaps reference for future test-maintenance work.
