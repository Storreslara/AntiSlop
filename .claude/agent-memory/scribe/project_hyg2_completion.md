---
name: hyg-2 completion
description: PASS 2026-10-05; fence_case check (c) fix + sigint_ignored job-control guard in probe-hook-identity.test.sh
metadata:
  type: project
---

hyg-2 (commit 50c90bc, 2026-10-05) ships two test hygiene fixes in `tests/probe-hook-identity.test.sh`:

**G3: fence_case check (c) fix** (line ~287)
- `fence_case()` counts every inner backtick-only line of N or more as its `ok` text states
- Previously dropped inner lines that equal the fence itself
- Mutant control: mutate `pane_fence()` to print fence length instead of +1; unfixed script says ok (false), fixed script says FAIL (correct)
- Proves non-vacuity with mutation: reverting fix makes test fail as expected

**G4: sigint_ignored() job-control guard** (line ~324, row I50)
- Guard reports FAIL instead of probing when job control is on
- Comment clarifies: safe only with `set +m` (job control off)
- Test runs with guard: `set -m` at start, `set +m` before guard (row int41)
- Added as new row I50 (not I44 as plan stated; I44–I49 taken by poc-1)

**Reviewer notes:**
- Row ID collision: poc-1 landed I44–I49 first, so hyg-2's guard became I50 instead of planned I44. Plan criterion 2 checked `grep -c '(I44)' = 0` against current suite (4 poc-1 lines match). I44–I49 rows verified untouched in diff.
- Criterion 5's base `fcfcc47` is stale; scope verified against own range `8dbe70d..50c90bc`.

**Plan:** docs/plans/2026-10-04-hygiene-cleanup.md (G3, G4 items).
