---
name: gwd-3_completion
description: PASS 2026-09-11; vendored-skill count 11→12; drift-tracked-skills 8→9 correction; grill-with-docs glossary entry added
metadata:
  type: project
---

**Unit**: gwd-3 (Grill With Docs, phase 3)
**Status**: PASS (marker at `.claude/reviewed/gwd-3.pass`, commit `21fdcfd2453f4289af77addb0ddb8ed3f55fcf53`)
**Date**: 2026-09-11

## Changes recorded

### File: `README.md`
- Line count update: "11 skills vendored first-party" → "12 skills vendored first-party"

### File: `docs/maintenance/resync-vendored-skills.md`
- Table row added: `grill-with-docs` skill, marked as `verbatim (flag stripped)`
- Vendored-skill count updated: 11→12 skills
- Deviation-count language updated: "8 verbatim skills" → "9 drift-tracked skills"
  - **Why this correction**: post gwd-1 correction—after `grill-me` and `grill-with-docs` shipped as `fm-noflag` deviations, the count of drift-tracked skills rose to 9 (not 8). The count language was out of sync; now reads: "byte-verbatim aside from their provenance header and four declared fm-noflag deviations"

### File: `CONTEXT.md`
- Added glossary entry: `**grill-with-docs skill**`
  - Links ADR-0031
  - Cross-links [[Preloaded skill]], [[`disable-model-invocation` flag]], [[description collision]]
  - Forward attribution: states that `spec-master` preloads `grill-with-docs` (unit gwd-4), parenthetical marked `(unit gwd-4)` to indicate future landed work
  - Notes `fm-noflag` declared-deviation class alongside `grill-me`
- Updated: `npm-distribution` entry reworded to drop brittle absolute count "only 2 of 17 skills" → count-free language
  - **Why**: prevents dated enumeration decay (ADR-0022's sentence references "2 of 18", but CONTEXT.md stays living)

## Known non-blocking reviewer findings (optional cleanup)

**Table labeling inconsistency**: `resync-vendored-skills.md`'s "What's vendored" table only marks two grill rows as `verbatim (flag stripped)`, but `handoff` and `improve-codebase-architecture` are also `fm-noflag` deviations (per ADR-0012 and ADR-0031). The paragraph below the table correctly lists all four, but the table itself disagrees. Status: documented as planned deviation (step 3.2 of the plan specified only the two grill rows), not an implementation slip. Self-healing once you're next touching that file.

**Line 27 phrasing**: sentence "The first 9 are byte-verbatim ... with four intentional deviations" is self-contradictory if taken literally (four of the nine aren't byte-verbatim). Reviewer suggested: "byte-verbatim aside from their provenance header and four declared fm-noflag deviations" — now used in the table label line.

## Forward contract

**Advisory**: `CONTEXT.md`'s new `grill-with-docs` entry claims in present tense that `spec-master` preloads it, but `agents/spec-master.md` doesn't list it in `skills:` until gwd-4 lands. The parenthetical `(unit gwd-4)` was written deliberately as forward attribution per the plan. This glossary claim will self-correct once gwd-4 PASSes; treat the entry as "reference from gwd-4's perspective" until then.

## Tree state

No scribe changes to commit—gwd-3 is a reviewer-PASSed unit. All changes were made by lead-programmer and already committed/reviewed. Scribe's role is solely to record this milestone in institutional memory.
