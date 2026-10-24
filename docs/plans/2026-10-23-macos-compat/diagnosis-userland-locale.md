# fableA: macOS (BSD userland / locale) failures in `bash tests/validate.sh`

Working copy: `/private/tmp/claude-501/-Users-sebas/8f0fc331-889a-4cf0-9be4-9b1cff60da52/scratchpad/wsA`
(baseline commit `e57c3d32` on branch `fableA-baseline` = snapshot of the working tree of
/Users/sebas/AntiSlop, uncommitted changes included). Patch: `fableA.patch` (= `git diff` of that copy;
`git apply --check` passes against a fresh clone of the baseline commit).

Environment used for every check: Darwin 25.6.0, `/bin/bash` 3.2.57, `LANG=en_US.UTF-8`,
`PATH="$PWD/tests/lib/bsd-shims:$PATH"` exactly as validate.sh:10 sets it, `/usr/bin/grep` (BSD),
`/usr/bin/awk` (BSD awk 20200816), `/usr/bin/sed` (BSD). No `timeout`/`gtimeout` on PATH.

Out of scope (owned by the other agent, left untouched): npm-pack KeyError, PyYAML `No module named
'yaml'` (agent frontmatter + `rendered explorer frontmatter`), `.claude/hooks/scripts` mirror drift,
persona-config fileHashes mismatches, `claude plugin tag` advisory.

---

## A1 - `exit 141` / SIGPIPE abort of the whole suite: BSD awk in the quiet filter dies on a non-UTF-8 byte

**Symptom (user run, quiet mode):**
```
awk: towc: multibyte conversion failure on: '�\233b' -> blocked'
 input record number 2252, file
 source line number 3
...
Counts: OK=1837 FAIL=31 WARN=1 SKIP=0
[exited with code 141]
```
**Where:** `tests/lib/validate-quiet.sh:9` (`validate_quiet_filter`, the `awk` that filters the stream);
the wrapper pipeline is `tests/validate.sh:37`
(`inner | tee "$skip_log" | validate_quiet_filter`, exit = `${PIPESTATUS[0]}`).

**Root cause:** `tests/human-decision-gate.test.sh:1461-1468` (PG20) prints its case labels with
`printf '%q'` under `LC_ALL=C`, which renders the probe `$'reason: a\xc2\x9bb'` as the raw byte `0xC2`
followed by `\233` - a lone UTF-8 lead byte, i.e. invalid UTF-8. BSD awk, running in the inherited
`en_US.UTF-8` locale, aborts (`towc: multibyte conversion failure`, rc=2) on the first such record
(record 2259 in my full log: `OK   PG20 [C] $'reason: a\xc2\233b' -> blocked`). With awk gone, `tee`
takes SIGPIPE on its next write, then the inner `bash tests/validate.sh` takes SIGPIPE on *its* next
write -> `inner_rc=141`. The summary then counts a truncated log (hence `OK=1837`), and every section
after PG20 never ran. gawk/mawk never abort on invalid bytes, which is why Linux never saw this.
(The "reviewed-path gate" header shown just above the error is only the last header the filter had
flushed; the crash is inside the human-decision gate section.)

**Fix:** run the filter's awk under `LC_ALL=C` (byte-oriented). This is the right fix rather than a
rewrite: the filter is a pure byte-stream line classifier, its two frozen regexes are unchanged, and
their multibyte literals (`⚠ ✗ ✓`) still match as byte sequences, so GNU and BSD awk classify every
line identically. The pin is local to that one `awk` invocation.

**Verification:**
- Reproduce with the baseline filter on the real 3175-line verbose log:
  `. <baseline validate-quiet.sh>; cat fullrun1.log | validate_quiet_filter` ->
  `awk rc=2`, `awk: towc: multibyte conversion failure on: '�\233b' -> blocked' ... input record number 2259`,
  114 output lines (matches the user's 119-line truncated output).
- Fixed filter on the same log: `awk rc=0`, 403 output lines, no stderr.
- `bash tests/validate-quiet.test.sh` (pins the frozen regexes and the wrapper behaviour): `rc=0`, "All validate-quiet cases passed."
- Full quiet-mode run after the patch: see "Final full run" below.

**Same pattern elsewhere:** `grep -rn awk tests/*.sh tests/lib/*.sh` - the only awk that consumes the
*whole suite stream* is this one. `tests/validate-lanes.sh:65,73` awk only parse `tests/validate.sh`
itself (ASCII). Hook scripts that regex over tool input already pin `LC_ALL=C` locally
(`hooks/scripts/human-decision-gate.sh:90,216,438`, `dispatch-hygiene.sh:92`, `lib/agent-identity.sh:120`).

## A2 - `sed: ... unused label 'a;N;$!ba;...'` (GNU-only sed one-liner) in the caller-allowlist derivation

**Symptom:**
```
== reviewer-route-gate caller allowlist (Bash) ==
sed: 2: ":a;N;$!ba;s/\\\n[[:spac ...": unused label 'a;N;$!ba;s/\\\n[[:space:]]*/ /g'
```
**Where:** `tests/reviewer-route-gate-caller.test.sh:166`
(`joined="$(sed -E ':a;N;$!ba;s/\\\n[[:space:]]*/ /g' "$1")"` in `derive_caller_allowlist_literals`).

**Root cause:** BSD sed reads a label to end of line, so `:a;N;$!ba;s/...` is one label named
`a;N;$!ba;s/\\\n[[:space:]]*/ /g`; it warns and - silently, rc=0 - passes the file through *unjoined*.
The test still passed only because the three `\`-continued lines in reviewer-route-gate.sh do not
currently split a `persona_matches_gate` call; the derivation was unverified noise on macOS.

**Fix:** replace the sed with an awk loop that joins `\`-newline (plus the next line's leading
whitespace, and any blank lines in between, exactly like `[[:space:]]*` after `\n`) into one space.

**Verification:**
- Equivalence on the real input: `diff <(perl -0777 -pe 's/\\\n\s*/ /g' hooks/scripts/reviewer-route-gate.sh) <(awk '...' same)` -> identical
  (perl -0777 is the GNU-sed semantics reference). Also on a synthetic file with `a \`+indented `b`,
  `c\`+blank line+indented `d`: both give `a  b` / `c d` / `e`.
- `bash tests/reviewer-route-gate-caller.test.sh`: before = 0 FAIL lines + the sed warning; after = 0 FAIL lines, no stderr.

**Same pattern elsewhere:** `grep -rnE 'sed[^|]*(:a;|\$!ba|\$!N|-z |--null-data)'` over the repo
(excluding docs/tmp/specs/node_modules): no other hit.

## A3 - `tests/microworld/microworld-rerun.test.sh` FAIL: every bundle logs `result=fail` because `_portable_timeout` returns 125 without `timeout`

**Symptom:** 17 FAIL lines, e.g.
`FAIL (c) expected exit 0 and a result=pass audit line (rc=0 log=[... unit=widget result=fail file=src/app.js authority=self])`,
`(d2) ... expected ... result=timeout`, `(h3) ... trace-exists=no`, `(i) suite_runs=0`, `(k) rc1=MISSING`,
`(g) cursor/codex mirror parity broken (pass-rc=0 fail-rc=0)` -> `FAIL tests/microworld/microworld-rerun.test.sh`.

**Where:** `hooks/scripts/lib/portable-tools.sh:38-53` (`_portable_timeout`), called from
`hooks/scripts/lib/microworld-queue.sh:143` and `:166` (the drain loop runs every bundle `run.sh` and
watch-map command through it).

**Root cause:** a macOS defect, not by-design. Stock macOS has neither `timeout` nor `gtimeout`;
`_portable_timeout` then prints "timeout command not found" and returns 125, so the queue maps every
bundle - pass, fail or slow - to `result=fail` (125 is neither 0 nor 124). `tests/lib/bsd-shims/README`
states there is deliberately no `timeout` shim ("the hooks must keep working without one"), so the lib
itself must degrade gracefully.

**Fix:** keep `timeout`/`gtimeout` when present; otherwise a pure bash-3.2 watchdog: run the command in
the background (stdin passed through like `timeout`), a sleeper subshell sends SIGTERM after N seconds,
and the result is 124 only when that kill landed on a still-running command (the watchdog's exit status
is `kill`'s). The watchdog's TERM trap reaps its own `sleep`, so a fast command leaves no stray process;
bash's "Terminated: 15" job notice is silenced. Same bytes copied to the three mirrors
(`.claude/hooks/scripts/lib`, `adapters/codex/...`, `adapters/cursor/...`) so the
"shared hook libs"/mirror-parity sections do not regress (portable-tools.sh has no fileHashes entry,
so the persona-config baseline is unaffected).

**Verification** (`PATH=/usr/bin:/bin:/usr/sbin:/sbin`, i.e. no timeout binaries):
- `_portable_timeout 1 sleep 5` -> rc=124 in 1s; `_portable_timeout 5 sh -c 'exit 3'` -> 3;
  `_portable_timeout 5 true` -> 0; stdin passthrough `sh -c 'echo hi; cat' <<<stdin-ok` -> `hi\nstdin-ok`;
  `pgrep -lf 'sleep 5$'` afterwards -> none; `_portable_timeout 1 bash -c 'sleep 30'` -> 124.
- `bash tests/microworld/microworld-rerun.test.sh`: before rc=1 (17 FAIL); after rc=0, 27 OK, 0 FAIL.
- Dependents still green: `tests/stop-gate-deferred-microworld.test.sh`, `tests/stop-gate-microworld-skip.test.sh`,
  `tests/session-start-microworld-status.test.sh`, `tests/hook-latency-budget.test.sh`,
  `tests/adapter-stop-gate-parity.test.sh` all rc=0.

**Same pattern elsewhere:** bare `timeout N` remains in `scripts/probe-bash-ask.sh:101`,
`scripts/probe-hook-identity.sh:198` and `prototype/outcomeci-series-gate/{preflight.sh:52,tests/preflight.test.sh:60}`
(already listed by `python3 -I scripts/portable-convert.py --check`). They are manual probe/prototype
scripts, not run by validate.sh; not changed.

## A4 - `tests/validate-lanes.sh` runs sections without the bsd-shims PATH on Darwin

**Symptom:** under the lane runner, every shim-dependent section fails on macOS, e.g.
`touch: out of range or illegal time specification: YYYY-MM-DDThh:mm:SS[.frac][tz]` / `FAIL tests/review-join.test.sh`,
`sed: 1: "/var/folders/...": invalid command code f` / `FAIL tests/stop-gate-blocked.test.sh`.

**Where:** `tests/validate-lanes.sh:109` (the generated per-section preamble
`set -uo pipefail; cd <lane>; fail=0`).

**Root cause:** the lane runner cuts `tests/validate.sh` at its `echo "== ` headers; the Darwin PATH
line (`validate.sh:10`) sits above the first header, so no section body carries it and every lane
copy runs BSD sed/touch/date/wc unshimmed. Found while reading how to run sections individually (scope item 3).

**Fix:** add the identical Darwin PATH line to the generated preamble (pointing at the lane copy's own
`tests/lib/bsd-shims`).

**Verification:** a scratch copy with `tests/validate.sh` trimmed to the review-join and
stop-gate-blocked sections, `bash tests/validate-lanes.sh --lanes 1`: baseline runner -> both FAIL with
the errors above; patched runner -> both OK, "All checks passed." `bash tests/validate-lanes.test.sh` rc=0.
Direct evidence of shim dependence: `review-join`, `stop-gate-blocked`, `stop-gate-escalated`,
`human-review-cleanup`, `harness-config-drift`, `agent-identity-lib` tests return 1 with a plain PATH and 0 with the shims.

## A5 - `case 26 sweep: 381 probes, gate ALLOWED 248 of them` - by design, not a defect

`tests/reviewed-path-gate.test.sh:417` prints this informational line unconditionally (it is indented, so the
quiet filter passes it through - same on Linux). The comment at :420-422 records the measured value on
the fixed gate as exactly "248 of 381"; the assertion at :423 is a non-vacuity floor (>= 200) and passes.
The sweep is one-directional (an ALLOW is only a failure if real bash then touches the marker dir), and
no `case 26` FAIL line appears in the full verbose log. No change.

## A6 - `cut: stdin: Illegal byte sequence` / `sed: RE error: illegal byte sequence` - not produced by the suite

Full verbose log (binary-safe grep: `LC_ALL=C grep -a -n -i 'illegal byte|RE error|^cut: |^sed: '`) contains
only the A2 sed warning. BSD `cut -c` *does* fail that way on the PG20 lines (I reproduced it when I
piped the log through `cut -c1-150` myself), so these messages come from post-processing the log with
BSD cut/sed under a UTF-8 locale, not from validate.sh. Anyone doing that should use `LC_ALL=C`.
No change.

## A7 - reviewed-dir leak guard passes vacuously on macOS: `find: -printf: unknown primary or operator`

**Symptom (verbose log only, line 4587):**
```
== reviewed-dir leak guard: no suite leaks fixtures into .claude/reviewed/ (Bash, gh425) ==
find: -printf: unknown primary or operator
OK   no suite wrote into CLAUDE_PROJECT_DIR's .claude/reviewed/ during a full validate.sh run
```
**Where:** `tests/reviewed-dir-leak-guard.test.sh:68`
(`leaked="$(find "$sandbox/.claude/reviewed" -mindepth 1 -printf '%P\n' | sort)"`).

**Root cause:** `-printf` is GNU find only. BSD find exits 1 with no output, so `$leaked` is empty and the
guard reports OK whatever is in the directory - the check was silently disabled on macOS (a weakened
check hidden behind an OK line, the opposite of a false FAIL).

**Fix:** list with plain `find -mindepth 1` and strip the prefix with `${e#"$dir"/}` in a `while read`
loop (the same construct `tests/validate-lanes.sh:81-84` already uses for the same reason).

**Verification:** fixture dir with `a.pass`, `sub/`, `sub/b.pass`: `/usr/bin/find ... -printf '%P\n'` ->
`find: -printf: unknown primary or operator`, empty output, rc=1; portable form -> `a.pass`, `sub`,
`sub/b.pass` (identical to GNU `%P`). `bash -n` passes. The post-patch full run exercises the real test
(see below).

**Same pattern elsewhere:** `grep -rn 'find .*-printf'` over tests/, hooks/, bin/, scripts/: no other use.

## A8 - `tests/rollout-preflight.test.sh`: 12 FAILs because `scripts/rollout-preflight.sh` refuses bash 3.2

**Symptom (verbose log 4495-4507):** `FAIL W0: did not report live CI conclusion (success)`, `FAIL W9: did not
list all three predecessors (W3, W7, W8)`, ... `FAIL W10: did not report properly`, `FAIL tests/rollout-preflight.test.sh`.
Running the script directly: `/bin/bash scripts/rollout-preflight.sh W9` -> `rollout-preflight.sh: needs bash >= 4 (macOS: brew install bash)`.

**Where:** `scripts/rollout-preflight.sh:17-21` (explicit `BASH_VERSINFO[0] -lt 4` refusal; seven
`declare -A` tables at :28-:119); `tests/rollout-preflight.test.sh` invoked it 24 times as `bash "$SCRIPT"`.

**Root cause:** bash-version, not BSD userland: the checker is built on associative arrays and refuses 3.2
by design; its own header calls it rollout scaffolding to be deleted. No bash >= 4 exists on this machine
(`/bin/bash` only; no `/opt/homebrew/bin/bash`, `/usr/local/bin/bash`), and brew installs are off limits.

**Fix (judgment call - flagging it):** I did NOT port the 516-line script to bash 3.2. The test now looks for
a bash >= 4 (`bash` on PATH, then `/opt/homebrew/bin`, `/usr/local/bin`, `/opt/local/bin`) and runs the
checker with it; if none exists it prints one `SKIP tests/rollout-preflight.test.sh (scripts/rollout-preflight.sh
needs bash >= 4; only bash 3.2.57(1)-release found)` and exits 0. On Linux/CI `bash` is >= 4 and the test is
unchanged. This is the suite's established prerequisite pattern (`SKIP locale (no localedef)`,
`SKIP git index mode check`) and the SKIP is counted in validate.sh's advisory summary, so it is visible,
not hidden. If the caller prefers a hard FAIL on macOS until the script is ported or deleted, revert this
hunk of the patch; the rest is independent.

**Verification:** `/bin/bash tests/rollout-preflight.test.sh` -> the SKIP line, rc=0. Discovery proven with a
stub `bash` on PATH that answers `BASH_VERSINFO[0]=5`: the test selects it and proceeds to the W-assertions
(they then fail against the stub, as expected). `grep -c 'bash "\$SCRIPT"'` -> 0 remaining bare invocations.

## A9 - `tests/cli-backfill.test.js` FAILs (verbose log 3176, 3311, 3315, 3354, 3516): not BSD/locale - fileHashes drift (other agent)

The messages are `Note: persona-config.json was missing some substitutions/fileHashes entries ... 3 hook script(s)
had no recorded fileHashes baseline ... Affected: .claude/hooks/scripts/lib/portable-tools.sh, adapters/codex/...`
and `got: M .claude/persona-config.json`. That is the fileHashes/mirror state of the checkout (portable-tools.sh
has no fileHashes entry yet), which the other agent owns. Not touched. Note for them: my A3 change edits
`hooks/scripts/lib/portable-tools.sh` and its three mirrors byte-identically, so a `node bin/cli.js --update
--force-render` after both patches will record the new content.

Also seen only in the verbose log and out of scope: `tests/eval-cases.test.sh` (PyYAML).

---

## Final full run after the patch

`/bin/bash tests/validate.sh` (quiet mode, the user's invocation) on the patched copy:
- exit code **1** (genuine FAILs), no longer 141; the run reaches the end of the suite:
  `Counts: OK=3265 FAIL=36 WARN=1 SKIP=1` (user's aborted run: `OK=1837`), 441 output lines.
- No `awk: towc`, no `sed: ... unused label`, no `illegal byte sequence`; `tests/microworld/microworld-rerun.test.sh`
  and `reviewer-route-gate caller allowlist` are green.
- Every remaining FAIL is out of my scope and unchanged: npm pack KeyError (1), PyYAML `No module named 'yaml'`
  (agent frontmatter x10, rendered explorer frontmatter x1, eval-cases x3), `.claude/hooks/scripts` mirror drift (1),
  fileHashes (2), `tests/cli-backfill.test.js` (5, fileHashes - see A9).
- Timing note: this run was started before the A7/A8 edits landed, so its "rollout wave-graph preflight" and
  "reviewed-dir leak guard" sections still show the pre-fix behaviour (12 W-FAILs; `find: -printf: unknown primary
  or operator`). Both were then verified individually on the final tree (A7: fixture before/after; A8:
  `/bin/bash tests/rollout-preflight.test.sh` -> one SKIP, rc=0). With A8 applied the expected final count is
  FAIL=23 SKIP=2, all 23 out of scope.

The baseline verbose run (`ANTISLOP_VALIDATE_INNER=1 /bin/bash tests/validate.sh`, 5166 lines, 176 section headers
incl. the nested leak-guard run) is at `scratchpad/fullrun1.log`; the post-patch quiet run at `scratchpad/quietrun-after.log`.

## Not fixed / left as-is
- A8 is a precondition SKIP, not a port of `scripts/rollout-preflight.sh` to bash 3.2 (see A8 for why and how to revert).
- Out-of-scope FAILs listed above (other agent). Hand-edits to `.claude/persona-config.json` fileHashes were deliberately not made.
- Bare `timeout` in `scripts/probe-*.sh` and `prototype/` (not run by validate.sh) left for the portable-convert backlog.
