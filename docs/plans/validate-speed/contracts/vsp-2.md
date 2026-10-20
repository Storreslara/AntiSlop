Unit: vsp-2

## Objective
The reviewed-dir leak guard stops re-running the whole of `tests/validate.sh` inside itself.
- The serial run (`--serial`) gives its sections a fresh sandbox `CLAUDE_PROJECT_DIR` holding an empty
  `.claude/reviewed/`, checks the sandbox after the inner run, FAILs the run when anything appeared there or the
  directory is gone, and then removes the sandbox. The caller's own project directory never receives a leak.
- `tests/reviewed-dir-leak-guard.test.sh` becomes a fast self-test of that check, with no nested run.
- The lane runner (the default since vsp-1) keeps its own per-section fingerprint and stops setting
  `REVIEWED_DIR_LEAK_GUARD_NESTED`.

This is spec Step 2 (alternative A). It lands on top of vsp-1.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/validate-speed/spec.md`, "Step 2 (vsp-2)" and "Context" (the notes
sweep dispositions for this test). This file is the contract of record.

## Affected files
- `tests/lib/reviewed-dir-guard.sh` (new): a setup function that prints a fresh sandbox path (mktemp, holding an
  empty `.claude/reviewed/`), and a check function that takes the sandbox, prints a section headed
  `reviewed-dir leak guard` with an OK line or FAIL lines naming every entry found ("reviewed-dir leak" in the FAIL
  text), and returns non-zero on a leak or a missing directory.
- `tests/validate.sh`: the skip-summary wrapper block only (serial branch).
- `tests/reviewed-dir-leak-guard.test.sh`: rewritten.
- `tests/validate-lanes.sh`: the header comment about section 101 and the `REVIEWED_DIR_LEAK_GUARD_NESTED=1`
  assignment.
- `tests/validate-lanes.test.sh`: the two `env -u REVIEWED_DIR_LEAK_GUARD_NESTED` uses.
- `CONTRIBUTING.md`: any remaining sentence about the guard's nested run.

## Ordered edits
1. Write `tests/lib/reviewed-dir-guard.sh` as described above. It is sourced, not executed (mode 644, like the
   other `tests/lib/*.sh`).
2. In the wrapper's serial branch: source the helper, create the sandbox, run the inner script with
   `CLAUDE_PROJECT_DIR` set to the sandbox, then run the check. If the check fails, the wrapper's exit code is
   non-zero even when the inner run passed. Remove the sandbox. The lanes branch is unchanged. Keep everything
   above the `# <<< skip-summary wrapper` line.
3. Rewrite `tests/reviewed-dir-leak-guard.test.sh`: source the helper and check three cases. An empty sandbox
   passes. A sandbox with a planted entry fails and names the entry. A sandbox whose `.claude/reviewed/` was
   removed fails. Use `cd "$(dirname "$0")/.." || exit 1` (gh425-2 note 2). Never invoke `tests/validate.sh`.
   Exit 0 only when all three hold. Keep a header comment saying where the leak check now lives (the serial
   wrapper, plus the lane runner's per-section fingerprint for the default run).
4. In `tests/validate-lanes.sh`, drop `REVIEWED_DIR_LEAK_GUARD_NESTED=1` and the comment sentence about section 101's
   nested guard. In `tests/validate-lanes.test.sh`, drop `-u REVIEWED_DIR_LEAK_GUARD_NESTED` from both `env`
   calls.
5. In CONTRIBUTING.md, remove any sentence about the guard's nested run, and say that the serial run checks its
   own sandbox.
6. Commit with the subject `perf(vsp-2): the reviewed-dir leak guard no longer re-runs the whole suite`.

## Do NOT touch
- Any section of `tests/validate.sh` below the wrapper block, including the reviewed-dir leak guard section's
  header text and its `bash tests/reviewed-dir-leak-guard.test.sh` call.
- The lanes branch of the wrapper and the lane runner's copy and fingerprint logic (vsp-1 owns them).
- Earlier plans' criteria under `docs/plans/*-criteria/` (some set `REVIEWED_DIR_LEAK_GUARD_NESTED`; once unused,
  it is harmless).
- `.claude/persona-config.json`, `hooks/`, `agents/`, `templates/`, `adapters/`, `eval/`, `tests/abtest-*`.
- `docs/harness-glossary.md`, `CONTEXT.md` (scribe, after PASS). Never call this guard "leak guard" alone: that
  glossary term is the eval's `abt_leak_guard`.

## Acceptance criteria
All from the repository root.
- AC2.1 run: `bash tests/reviewed-dir-leak-guard.test.sh` (exit 0) and
  `! grep -nE '^[^#]*tests/validate\.sh' tests/reviewed-dir-leak-guard.test.sh` (exit 0). mutation: making the
  check function `return 0` unconditionally makes the test exit 1; at the baseline the grep finds line 51.
- AC2.2 run: `bash docs/plans/validate-speed/criteria/vsp2-ac2.sh` (exit 0). mutation: at the baseline G1-G4 and
  G6 FAIL; removing the sandbox `CLAUDE_PROJECT_DIR` assignment FAILs G2 and G3.
- AC2.3 run: `bash tests/validate-lanes.test.sh` (exit 0) and
  `! git grep -n REVIEWED_DIR_LEAK_GUARD_NESTED -- tests CONTRIBUTING.md README.md` (exit 0). mutation: at the
  baseline the git grep lists three files.
- AC2.4 run: `bash docs/plans/validate-speed/criteria/real-run.sh` with the Bash tool's timeout at 600000 ms, with
  no other validate.sh run in progress (exit 0, last line `real-run: PASS`).
- AC2.5 run: `! grep -qF 'nested run' CONTRIBUTING.md` (exit 0).

## Pre-resolved context
- Why the nested run can go: it existed only to run every section with a sandbox `CLAUDE_PROJECT_DIR` and look at
  the sandbox afterwards. It took about 882 s of the 1729 s full run (spec Context, rank 1). The serial run itself
  now runs under that sandbox. The nested run already proves every section passes with a sandbox
  `CLAUDE_PROJECT_DIR`.
- The sandbox must start empty. An overwrite of a marker name the caller already has then shows up as a new entry
  (gh425-2 note 3).
- The default run (lanes) is unaffected: each lane sets `CLAUDE_PROJECT_DIR` to its own copy and fingerprints the
  copy's `.claude/reviewed/` around every section. That also sees repo-root-relative writes, which the serial
  sandbox cannot.
- `reviewed-path-gate.sh` blocks Bash command text that spells the reviewed-markers path in a write position. Write
  new files with the Write tool, and keep the path out of the Bash command text.
- The criteria scripts in `docs/plans/validate-speed/criteria/` are committed and part of the contract. Do not edit
  them; report one you believe is wrong. A scratch prototype passed AC2.2 with a 9-line helper.

## Escalation
If AC2.4 is red on a section that is also red at vsp-1's final commit (the `test(vsp-1): ...` commit on top of e4e452c0), report it and stop. If removing the env
variable from the lane runner changes any lane-runner test outcome, report the case. If a gate blocks a write,
report it and wait. Changes outside "Affected files" go to the report as proposals.
