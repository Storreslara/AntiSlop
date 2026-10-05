---
name: ocig-1 completion
description: PASS 2026-10-05; four glossary entries added to CONTEXT.md; known gaps recorded
metadata:
  type: project
---

**ocig-1b (OutcomeCI Series-Gate Trial Phase 0 — Scribe Post-Review)**: PASS 2026-10-05. Reviewer PASS line: "PASS ocig-1b (commit 2c14072924ffc6a2ec0f4e9ab74af326a9e42ac9)". Lead-programmer unit built the externalization precondition wrapper and test/mutation suites for the OutcomeCI Design A series-gate trial. Scribe task updates completion record with final findings.

## Scribe completion

Four glossary entries added to CONTEXT.md:
1. **externalization** — action that makes effects leave the machine (push, PR, issue close, chat post)
2. **externalization precondition wrapper** — host script refusing to start externalizing run unless PASS marker is valid and commit-bound
3. **broker journal** — OutcomeCI's per-run record at `.outcomeci/.broker/<run>/journal.json`
4. **policy decision** — allow/revise/deny from policy review; never a verdict, never counts toward 2-FAIL cap

All entries cross-linked and in existing glossary style. No version-stamp requirement (CONTEXT.md not a version-stamped file).

## Gaps closed by ocig-1b

These three gaps from the original ocig-1 trial are now resolved:
- **mutation-proof.sh exit code**: now exits non-zero when a mutant survives (mutation-proof exit code mutation test in T9 verifies this)
- **helper script stderr**: wrapper's stderr contract is now exactly one `series-gate=refuse|allow ...` line, plus `oci`'s own output on the allow path (measured in T9 with noisy-shim hooks dir)
- **weak T5b/T8 assertions**: assertions strengthened to verify `oci` was called and `allow` line present in the wrapper's output

## Known gaps (reviewer notes, non-blocking — do not fix)

These gaps are acknowledged non-blocking findings suitable for future maintenance or design refinement, not blockers for the trial's Phase 0 completion.

- **AC1.5**: marker directory (`.claude/reviewed/`) is gitignored, making marker-check weakness observable (structural weakness in the check itself, not the trial's code)
- **AC1.6**: spec uses `..HEAD` syntax; should clarify whether this means `git diff --name-only <base>..HEAD` or another interpretation
- **marker line 1 TOCTOU**: marker line 1 is read three times (R2 existence check, R3 format validation, R6 execute), creating time-of-check vs time-of-use risk if another session edits the marker between checks (documented as R1/R7 residual in the spec)

## Reviewer advisory notes (cosmetic, non-blocking)

- **check_oci_called timing**: `check_oci_called` runs after `check` has printed "ok", creating a cosmetic double-report on failure when both checks detect failure. Harmless because error path terminates immediately.
- **T9 bin reassignment**: T9 reassigns the `bin` variable without restoring it afterward. Harmless only because T9 is the last test in the suite and no code runs after it.
