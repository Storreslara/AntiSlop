---
name: gwd-2_completion
description: PASS 2026-09-11; ADR-0031 + description collision glossary entry + ADR-0012 amendment
metadata:
  type: project
---

**Unit gwd-2 PASS** (marker at `.claude/reviewed/gwd-2.pass`, commit `357971d`).

## What landed

- **New file**: `docs/adr/0031-grill-with-docs-model-invocable.md` — records that `grill-with-docs` is vendored as an `fm-noflag` declared deviation and `grill-me` is converted from `fm` (byte-verbatim) to `fm-noflag`, reversing ADR-0012's prior "grill-me is the control, deliberately left alone" decision. The `fm-noflag` set is now four skills (`handoff`, `improve-codebase-architecture`, `grill-me`, `grill-with-docs`). Records the "description collision" accepted risk (two near-identical skill descriptions that cannot be disambiguated via edits because both are drift-tracked). Establishes the `spec-master` / `scribe` boundary: `spec-master` writes `CONTEXT.md` glossary entries directly during grilling, but only drafts ADRs into plans for `scribe` to number and land.

- **Changed**: `docs/adr/0012-vendored-skill-declared-deviations.md` — annotation-only amendment. `Status:` line now reads "Accepted (amended by ADR-0031)"; new `## Related` bullet names the specific now-stale rows/sentences (the `grill-me` row in the asymmetry table, and the "grill-me is the control" sentence). Both ADR bodies remain byte-for-byte unchanged (diff+checksum verified by reviewer).

- **New glossary entry**: `CONTEXT.md` — **description collision** entry added (scribe post-dispatch) explaining the accepted risk that two model-invocable `grill-*` skills have near-identical drift-tracked descriptions that cannot be disambiguated; mitigation is prose naming only.

## Known non-blocking defects

1. **Stale line-number anchor** (NOTE[code]): ADR-0031:17 cites `CONTEXT.md:1027` for the `disable-model-invocation` glossary entry; the scribe's concurrent commit `1aae447` shifted that entry to line 1037. Only the line number is stale; the quoted text is correct. This is a known trap: when multiple commits land concurrently in different files, line-number cross-references can drift.

2. **Escaped backticks render with backslashes** (NOTE[code]): ADR-0012:85-86 and ADR-0031:71 quote the asymmetry table row using `\`` inside markdown code spans, which renders with visible backslashes. Cosmetic; the plan text used the same escaping.

3. **Description collision is a new domain concept** (NOTE[spec]/lens-3): Load-bearing term with no prior glossary entry; reviewer recommended scribe add one. Glossary entry now landed (see above).

## Why this matters

The `description collision` acceptance is critical context for `gwd-4` (the unit that pivots a persona onto `grill-with-docs`), which won't land if this concept isn't documented. The pivot itself (prose naming in persona instructions) is the only defense against the harness selecting `grill-me` when a user says "grill" — the skill names themselves are identical in the context list.
