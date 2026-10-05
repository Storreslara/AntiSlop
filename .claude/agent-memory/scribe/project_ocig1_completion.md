---
name: ocig-1 completion
description: PASS 2026-10-05; four glossary entries added to CONTEXT.md; known gaps recorded
metadata:
  type: project
---

**ocig-1 (OutcomeCI Series-Gate Trial Phase 0)**: PASS 2026-10-05. Lead-programmer unit to build the externalization precondition wrapper and test/mutation suites for the OutcomeCI Design A series-gate trial.

## Scribe completion

Four glossary entries added to CONTEXT.md:
1. **externalization** — action that makes effects leave the machine (push, PR, issue close, chat post)
2. **externalization precondition wrapper** — host script refusing to start externalizing run unless PASS marker is valid and commit-bound
3. **broker journal** — OutcomeCI's per-run record at `.outcomeci/.broker/<run>/journal.json`
4. **policy decision** — allow/revise/deny from policy review; never a verdict, never counts toward 2-FAIL cap

All entries cross-linked and in existing glossary style. No version-stamp requirement (CONTEXT.md not a version-stamped file).

## Known gaps (reviewer notes, non-blocking — do not fix)

- **AC1.5**: marker directory (`.claude/reviewed/`) is gitignored, making marker-check weakness observable (structural weakness in the check itself, not the trial's code)
- **AC1.6**: spec uses `..HEAD` syntax; should clarify whether this means `git diff --name-only <base>..HEAD` or another interpretation
- **mutation-proof.sh exit code**: exits 0 even when a mutant survives (does not fail on mutant survival, only on suite failure)
- **helper script stderr**: helper scripts invoked by the wrapper may write extra stderr lines beyond the one-line spec (series-gate=allow/refuse line)
- **marker line 1 TOCTOU**: marker line 1 is read three times (R2 existence check, R3 format validation, R6 execute), creating time-of-check vs time-of-use risk if another session edits the marker between checks (documented as R1/R7 residual in the spec)

These gaps are acknowledged non-blocking findings suitable for future maintenance or design refinement, not blockers for the trial's Phase 0 completion.
