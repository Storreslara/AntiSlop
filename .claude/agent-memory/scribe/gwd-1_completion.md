---
name: gwd-1_completion
description: Unit gwd-1 (scribe) completion — recorded fm-noflag set now four skills, added drift-tracked-skills glossary entry, updated dependencies.md
metadata:
  type: project
---

## Unit gwd-1 completion (2026-09-11)

Unit gwd-1 just received a PASS verdict from the reviewer. This was the first step in the 4-unit plan `docs/plans/2026-09-11-grill-with-docs-vendoring-and-spec-master-pivot.md`, which vendors the new `grill-with-docs` skill and makes both it and `grill-me` model-invocable by stripping their `disable-model-invocation` flags.

### Scribe work completed

1. **Updated CONTEXT.md** with two additions:
   - New entry **"fm-noflag set now four skills"** (after the existing "Skills-library remediation completed" entry) documenting that the `fm-noflag` class now applies to four skills: `handoff`, `improve-codebase-architecture`, `grill-me`, and `grill-with-docs`. This supersedes the earlier "grill-me is the control" framing from ADR-0012.
   - New glossary entry **"drift-tracked skills"** (inserted after "`disable-model-invocation` flag" entry) explaining that it's the set of 9 vendored mattpocock skills byte-diffed by `scripts/resync-vendored-skills.sh`, checked via `fm` or `fm-noflag` reconstruction types. This addresses the advisory finding from the reviewer's ubiquitous-language check (originally flagged as non-blocking but cheap to add).

2. **Updated `.claude/wiki/dependencies.md`**:
   - Changed vendored skill count from 11 to 12
   - Added `grill-with-docs` to the skill list (in alphabetical order after `grill-me`)
   - Updated the description of `fm-noflag` deviation to list all four skills now receiving this treatment
   - Added reference to ADR-0031 (the amendment to ADR-0012)

### Notes for future steps

- Step 2 (gwd-2) will create ADR-0031 (amending ADR-0012) with detailed rationale for the reversal
- Step 3 (gwd-3) will mint the `grill-with-docs` glossary entry (scribe should verify rather than re-mint when that lands)
- Step 4 (gwd-4) will pivot `spec-master`'s interrogation onto `grill-with-docs` and bump the version
- The `grill-with-docs` glossary entry expected in Step 3 is not yet created — will verify when gwd-3 lands

### Related CONTEXT.md forward references

- The new "fm-noflag set now four skills" entry references ADR-0031, which hasn't landed yet (unit gwd-2), but the reference is correct as per the plan
- The "drift-tracked skills" entry references [[REPOINT_SKILLS]], which is not currently a glossary entry — that's okay as a forward reference to future documentation

### Did not touch

Per instructions: no changes to the reviewed code files themselves (`skills/grill-with-docs/SKILL.md`, `skills/grill-me/SKILL.md`, `scripts/resync-vendored-skills.sh`, `skills/THIRD-PARTY-NOTICES.md`)
