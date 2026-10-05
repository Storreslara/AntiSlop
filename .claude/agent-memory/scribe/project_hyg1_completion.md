---
name: hyg-1 completion
description: PASS 2026-10-05; skip-summary wrapper + frozen-family-table residual-pin check in validate.sh
metadata:
  type: project
---

hyg-1 (commit 8dbe70d, 2026-10-05) ships two harness-hygiene improvements in `tests/validate.sh`:

**G1: Skip-summary wrapper** (lines 10–21, advisory only)
- Wraps the suite to count and list `SKIP` lines in the output
- Prints `Skipped checks: N` plus indented SKIP lines (advisory section, does not gate)
- Exit code matches inner run (not affected by the wrapper)
- Workaround for CI runs: `.github/workflows/validate.yml` installs only jq, triggering validate.sh's own claude-CLI section to print SKIP on every CI run. Making the count visible is better than failing the gate.
- Known issue: TERM sent to outer process alone is deferred by bash until inner pipeline finishes; a following SIGKILL leaks the tee temp file. Observed in wild: `/tmp/tmp.S44Tc1QbrV` (236 KB, 600-second run). Fix shape: run pipeline with `&` and `wait`.

**G2: Frozen-family-table residual-pin check** (~line 1191)
- Verifies every pin named in `docs/harness-glossary.md`'s frozen family table entry (today `pin N21`, `pin R5`) is an `allowed` row in `tests/human-decision-gate.test.sh`
- Checks the entry's claim "`NL1` is the only `TRACKED-OPEN` pin" matches the suite
- Disarms silently if the glossary claim is reworded or removed (no OK, no FAIL)
- Consistent with design but lacks an absent-claim signal

**Note on R3 split:** wrapper sits after prologue (lines 1–9), so split runs omit it (no summary printed); accepted.

**Reviewer note:** criterion 4's `git diff --name-only fcfcc47..HEAD` scope was stale (includes files from interleaved poc-1); unit's own range `3ddfa45..8dbe70d` prints exactly `tests/validate.sh`.

**Plan:** docs/plans/2026-10-04-hygiene-cleanup.md (G1, G2 items).
