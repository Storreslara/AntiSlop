Unit: macos-merge

## Objective
The (I48) mutants in `tests/probe-hook-identity.test.sh` target the live string `transcript_holds_prompt "$3"`, and `mutrun` returns non-zero without running the suite when its exact-once assert fails, so a stale target can no longer make I48a and I48c pass vacuously. This fixes the latest FAIL on `macos-merge`; nothing else changes.

## Retrieval
No tracker issue exists for this unit. The spec is `docs/plans/2026-10-23-macos-compat.md`; the defect text is the last block of the unit's FAIL record under the reviewed-marker directory (fetch with the Read tool).

## Affected files
- `tests/probe-hook-identity.test.sh` (anchor: line matching `  PROBE_MUTANT=1 PROBE_UNDER_TEST="$T/mut$1/scripts/p.sh" bash "$PWD/tests/probe-hook-identity.test.sh" 2>&1`)
- `tests/probe-hook-identity.test.sh` (anchor: line matching `  MOUT="$(mutrun 48a 'transcript_holds_prompt "$5"' 'false')"`)
- `tests/probe-hook-identity.test.sh` (anchor: line matching `  MOUT="$(mutrun 48c 'transcript_holds_prompt "$5"' 'true')"`)

## Ordered edits
1. file: `tests/probe-hook-identity.test.sh`
   anchor: line matching `  PROBE_MUTANT=1 PROBE_UNDER_TEST="$T/mut$1/scripts/p.sh" bash "$PWD/tests/probe-hook-identity.test.sh" 2>&1`
   before: `  PROBE_MUTANT=1 PROBE_UNDER_TEST="$T/mut$1/scripts/p.sh" bash "$PWD/tests/probe-hook-identity.test.sh" 2>&1`
   indent: 2
   after:
   ~~~
     [ -s "$T/mut$1/scripts/p.sh" ] || { echo "mutrun $1: target string not found exactly once" >&2; return 1; }
     PROBE_MUTANT=1 PROBE_UNDER_TEST="$T/mut$1/scripts/p.sh" bash "$PWD/tests/probe-hook-identity.test.sh" 2>&1
   ~~~
2. file: `tests/probe-hook-identity.test.sh`
   anchor: line matching `  MOUT="$(mutrun 48a 'transcript_holds_prompt "$5"' 'false')"`
   before: `  MOUT="$(mutrun 48a 'transcript_holds_prompt "$5"' 'false')"`
   after: `  MOUT="$(mutrun 48a 'transcript_holds_prompt "$3"' 'false')"`
3. file: `tests/probe-hook-identity.test.sh`
   anchor: line matching `  MOUT="$(mutrun 48c 'transcript_holds_prompt "$5"' 'true')"`
   before: `  MOUT="$(mutrun 48c 'transcript_holds_prompt "$5"' 'true')"`
   after: `  MOUT="$(mutrun 48c 'transcript_holds_prompt "$3"' 'true')"`
4. command: `git add tests/probe-hook-identity.test.sh && git commit -m "fix(macos-merge): I48 mutants target the live string and mutrun aborts on a stale target (#0)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `scripts/probe-hook-identity.sh`
- `tests/validate.sh`
- `.claude-plugin/plugin.json`

## Acceptance criteria
1. run: `grep -cF 'transcript_holds_prompt "$5"' tests/probe-hook-identity.test.sh`
   exit: 1
   stdout: `0`
   mutation: skip edits 2 and 3; stdout `2`, exit 0.
2. run: `grep -cF 'transcript_holds_prompt "$3"' scripts/probe-hook-identity.sh`
   exit: 0
   stdout: `1`
   mutation: this checks the premise (the script's live string); change the script's `"$3"` back to `"$5"` and stdout is `0`.
3. run: `grep -cF 'target string not found exactly once' tests/probe-hook-identity.test.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; stdout `0`, exit 1.
4. run: `bash tests/probe-hook-identity.test.sh 2>&1 | grep -c 'ok   (I48)'`
   exit: 0
   stdout: `3`
   mutation: skip edit 2; the 48a target is absent, mutrun returns early, I48 prints `FAIL (I48) false mutant survives` and stdout is `2`.
   proof: scratch copy with `'transcript_holds_prompt "$3"'` replaced by `'NOPE'` in the 48a line prints `mutrun 48a: target string not found exactly once` and `FAIL (I48) false mutant survives`.
5. run: `bash tests/probe-hook-identity.test.sh >/dev/null 2>&1`
   exit: 0
   stdout: `empty`
   mutation: skip edit 3 to `"$5"` and the suite exits 1 because the 48c target is absent.
6. run: `git log --format=%s -1`
   exit: 0
   stdout: `fix(macos-merge): I48 mutants target the live string and mutrun aborts on a stale target (#0)`
   mutation: skip edit 4; the subject differs.

A quiet-machine rerun is the only valid full-suite check: do not gate on a complete validate.sh run reporting FAIL=0 while the machine is loaded, since abtest-runner and hook-latency-budget flake under load. If criterion 5 fails, rerun it once on an idle machine before reporting.

## Pre-resolved context
tdd: no this unit edits a test file; the criteria are the check
blast-radius: tests/probe-hook-identity.test.sh:339
commit-message: fix(macos-merge): I48 mutants target the live string and mutrun aborts on a stale target (#0)
review-packet:
~~~
unit: macos-merge (#0)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
