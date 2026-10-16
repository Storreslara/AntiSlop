---
name: ptr-u3b-completion
description: ptr-u3b PASS 07bbbbc closed #557; contract files landed; glossary + ADR-0042 added; six OPEN follow-ups
metadata:
  type: project
---

PASS 07bbbbc closed #557. CONTEXT.md: amended **contract of record**, added **contract file** (legacy layout folded in); harness-glossary issue-body layout + standard path amended; ADR-0042 landed (no ADR index exists; 0007 hole left alone). Still to land: dispatch checkpoint (ptr-u8), quiet-mode/denial-anchor/F1-F3 terms, U11 ADR-0040 history line.

OPEN follow-ups (reviewer notes, not fixed):
1. orchestrator.md ~19/~456 fast path "dispatches from the plan document" vs spec-master "contract file": ptr-u8 fixes it; verify afterwards.
2. Unit with both lead and scribe contracts maps both to contracts/<task-id>.md; spec-master ruling needed (e.g. <unit-id>.scribe.md).
3. scripts/unit-outcomes.js ~159-163 reads only the fenced issue-body block, so post-U3b units report no contract; blocks the final NR2 guard-demotion measurement; untested.
4. No test pins the new layout (Contract file: line, commit subject, commit-before-dispatch).
5. orchestrator.md ~521-527 does not say a missing contract file is a slicing error to stop on.
6. orchestrator.md:527 overlong line.

**Why:** reviewer notes. **How to apply:** check these on any later touch of the named files.
