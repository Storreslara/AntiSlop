Unit: vsp-1

## Objective
`bash tests/validate.sh` runs its sections through the existing lane runner (`tests/validate-lanes.sh`) by default,
so the merge gate takes a few minutes instead of about 29, with every section still run.
- Default: lanes, count `ANTISLOP_VALIDATE_LANES` if set, else min(6, `nproc`), at least 1 (`nproc` failing counts as 1).
- `--serial` or `ANTISLOP_VALIDATE_SERIAL=1`: today's serial run, unchanged.
- Quiet mode, `--verbose`, the SKIP summary, the `Counts:` and `Full log:` lines and the exit code behave as today.
- The lane runner works from a linked git worktree, and its heaviest-first claim list names today's heavy sections.

This is spec Step 1 (alternative B).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/validate-speed/spec.md`, "Step 1 (vsp-1)", "Context" and "Risks".
This file is the contract of record.

## Affected files
- `tests/validate.sh`: the skip-summary wrapper block only (between `# >>> skip-summary wrapper` at line 10 and
  `# <<< skip-summary wrapper` at line 48). No section below line 48 changes.
- `tests/validate-lanes.sh`: the linked-worktree refusal (lines 38-42), the lane copy in `lane()` (lines 86-101),
  the `heavy=` line (line 64), the usage/header comment.
- `tests/validate-lanes.test.sh`: one new case for a linked worktree.
- `CONTRIBUTING.md`: the two `validate.sh` bullets (lines 30-39).
- `README.md`: the paragraph at line 116.
- `tests/validate-quiet.test.sh` (amendment 2026-10-19): one line in `run_stub()` (line 60), the `env` call only.
  It becomes:
  `(cd "$stub" && env -u ANTISLOP_VALIDATE_INNER -u ANTISLOP_VALIDATE_VERBOSE ANTISLOP_VALIDATE_SERIAL=1 STUB_RC="$rc" "$@"); echo "rc=$?"`
  No other line of the file changes; no assertion is added, removed or reworded.

## Ordered edits
1. In the wrapper block of `tests/validate.sh`, parse `--serial` next to `--verbose` (and read
   `ANTISLOP_VALIDATE_SERIAL=1`). When serial, run the inner script exactly as today. Otherwise run
   `bash tests/validate-lanes.sh --lanes "$lanes"` in its place, inside the same tee / quiet-filter pipeline, with
   `lanes` = `ANTISLOP_VALIDATE_LANES` or min(6, `nproc`), at least 1. Keep every line the wrapper prints after the
   inner run. The wrapper code must stay above the `# <<< skip-summary wrapper` line: the criteria splice the real
   wrapper into stub suites at that line.
2. In `tests/validate-lanes.sh`, accept a linked worktree (`.git` is a file): build each lane's `.git` as a private
   standalone directory from `git rev-parse --git-common-dir` without its `worktrees/` subdirectory, then put the
   worktree's own `HEAD` and `index` (from `git rev-parse --absolute-git-dir`) into it. A main checkout is copied as
   today. A copy failure stays a FAIL naming the tar exit statuses.
3. Replace the `heavy=` pattern with one naming at least: `abtest-runner`, `abtest-fixtures`, `probe-hook-identity`,
   `unit-outcomes`, `human-decision gate`, `abtest-probe`, and keep `configless write-deny` and `reviewed-path gate`.
4. Add a case to `tests/validate-lanes.test.sh` that runs the runner from a linked worktree of a throwaway tree and
   checks that a stub section sees the worktree's HEAD.
5. Rewrite the CONTRIBUTING.md bullets so that they contain, verbatim, the clause
   "`bash tests/validate.sh` runs the sections in parallel lanes by default". Follow it with: each lane is a
   private copy of the checkout, any section that changes a lane's `.claude/reviewed/` FAILs, and `--serial`
   gives the serial run. Remove the sentence "is an opt-in parallel run". Append this sentence, verbatim, to
   README.md's paragraph at line 116: "By default it runs the sections in parallel lanes; `--serial` runs them one
   after another."
6. Commit with the subject `perf(vsp-1): tests/validate.sh runs its sections in parallel lanes by default`.
   (Landed as e4e452c0.)
7. (Amendment 2026-10-19.) Make the one-line `run_stub()` edit in `tests/validate-quiet.test.sh` shown under
   Affected files, and land it as a SECOND commit on top of e4e452c0 (do not amend or squash e4e452c0), subject
   `test(vsp-1): validate-quiet stub runs the serial wrapper (ANTISLOP_VALIDATE_SERIAL=1)`. That commit is
   vsp-1's final commit.

## Do NOT touch
- Any section of `tests/validate.sh` below the wrapper block, and any section header text.
- `tests/reviewed-dir-leak-guard.test.sh` and the `REVIEWED_DIR_LEAK_GUARD_NESTED` variable: that is vsp-2.
- `.claude/persona-config.json` (`testAndLintCommand` stays `bash tests/validate.sh`), `hooks/`, `agents/`,
  `templates/`, `adapters/`, `.github/workflows/validate.yml`.
- Any `tests/abtest-*.test.sh`, anything under `eval/`, and any timing budget in any test. A timing assertion
  that flakes under lanes is reported, not widened.
- `docs/harness-glossary.md` and `CONTEXT.md` (scribe, after PASS).
- Earlier plans' criteria scripts under `docs/plans/*-criteria/`.

## Acceptance criteria
All from the repository root. Every criterion is evaluated at vsp-1's final HEAD, the edit-7 commit, not at
e4e452c0: AC1.4 and AC1.5's two further runs are run after the edit-7 commit lands (e4e452c0 alone is red on
section 142, `tests/validate-quiet.test.sh`).
- AC1.1 run: `bash docs/plans/validate-speed/criteria/vsp1-ac1.sh` (exit 0, last line `all cases passed`).
  mutation: at the baseline A1, A2, A5, A6 and A11 FAIL; making `--serial` a no-op FAILs A3.
- AC1.2 run: `bash docs/plans/validate-speed/criteria/vsp1-ac2.sh` (exit 0). mutation: at the baseline the runner
  exits 2 in a linked worktree, so W1-W3 and W6 FAIL.
- AC1.3 run: `for h in abtest-runner abtest-fixtures probe-hook-identity unit-outcomes 'human-decision gate' abtest-probe; do grep -E "^heavy=" tests/validate-lanes.sh | grep -qF "$h" || { echo "missing: $h"; exit 1; }; done`
  (exit 0). mutation: at the baseline it prints `missing: abtest-runner`.
- AC1.4 run: `bash docs/plans/validate-speed/criteria/real-run.sh` with the Bash tool's timeout at 600000 ms, with
  no other validate.sh run in progress (exit 0, last line `real-run: PASS`). mutation: at the baseline there is no
  `== lanes:` line and the run takes over 600 s.
- AC1.5 run: the AC1.4 command twice more, as two separate commands (exit 0 both times).
- AC1.6 run: `bash tests/validate-lanes.test.sh` (exit 0) and
  `grep -qF 'By default it runs the sections in parallel lanes;' README.md && grep -qF 'runs the sections in parallel lanes by default' CONTRIBUTING.md && grep -qF -- '--serial' CONTRIBUTING.md && grep -qF -- 'runs them one after another' README.md && ! grep -qF 'is an opt-in parallel run' CONTRIBUTING.md`
  (exit 0). mutation: at the baseline the grep chain exits 1, because neither sentence exists.
- AC1.7 run: `bash tests/validate-quiet.test.sh` (exit 0). mutation: at e4e452c0 (lanes default, no
  `ANTISLOP_VALIDATE_SERIAL=1` in `run_stub`) it exits 1: the stub tree has no `tests/validate-lanes.sh`, so the
  wrapper cases 'quiet mode returns the inner exit code (1)', 'quiet mode prints the FAIL line' and
  '--verbose prints every line' FAIL (observed at e4e452c0, spec-master, 2026-10-19: exit 1, 8 `^FAIL` lines).

## Pre-resolved context
- Timings and the reasons for this design are in the spec's Context. The existing runner at 6 lanes took 230.5 s
  on the real suite at 00b55a75 (exit 0, 141 sections; the suite has 142 sections since 68235153 added
  `bin-helpers-scaffold`, and `real-run.sh` counts headers live, so no criterion pins either number), against 1729 s serial. Serial work is about 845 s without the nested
  guard. The longest section is abtest-runner at 148 s, and it is the floor for any lane count.
- The lane runner already exists and is tested: private tar copy per lane, per-section fingerprint of the lane's
  `.claude/reviewed/`, heaviest-first claims, process-group cleanup (vlg-1..3, vln-1..4, all PASS). It sets
  `REVIEWED_DIR_LEAK_GUARD_NESTED=1`, so the nested guard does not run inside lanes. Leave that to vsp-2.
- The lane runner cuts sections at column-0 `echo "== ` lines from the first one up to the closing
  `if [ "$fail" -eq 0 ]; then` block. The wrapper's own `echo` lines are indented, so they are not cut.
- A scratch prototype (spec, "Verification record") passed all of AC1.1 and AC1.2 with about 10 wrapper lines and
  about 12 runner lines. It is not committed; write your own.
- The criteria scripts in `docs/plans/validate-speed/criteria/` are committed and part of the contract. Do not edit
  them. If you believe one is wrong, report it.
- Hooks run `testAndLintCommand` with a 600 s default timeout and cancel it silently past that. A default run that
  is too slow therefore stops gating, which is why AC1.4 bounds the run at 360 s.
- Convention (amendment 2026-10-19): any suite that splices the real wrapper block of `tests/validate.sh` into a
  stub tree and runs it must set `ANTISLOP_VALIDATE_SERIAL=1` for the stub, because a stub tree has no lane
  runner. Swept at e4e452c0: `tests/validate-quiet.test.sh` is the only suite that does this. The other
  wrapper-splicer is `docs/plans/validate-speed/criteria/lib.sh`, which copies `tests/validate-lanes.sh` into its
  tree on purpose. `tests/reviewed-dir-leak-guard.test.sh` runs the real tree with `ANTISLOP_VALIDATE_INNER=1`,
  which skips the wrapper. Every other `tests/` hit on `bash tests/validate.sh` is a marker string or a
  configured-command fixture, not a run.
- Linked worktrees exist under `.claude/worktrees/agent-*`. The runner refuses them today with exit 2
  (`tests/validate-lanes.sh:38-42`).

## Escalation
If the baseline real run is red before your change (at 68235153 `tests/writer-tier-consistency.test.js` FAILs in
every run; at 00b55a75 one review run FAILed `tests/abtest-runner.test.sh`), run each FAILing suite alone. If it also fails alone, report it and stop:
it is not this unit's defect. If a section passes serially but flakes in lanes (AC1.5), name the section and its
failing line, and stop without changing the section or its budget. If a gate blocks a write, report it and wait.
Changes outside "Affected files" go to the report as proposals.
