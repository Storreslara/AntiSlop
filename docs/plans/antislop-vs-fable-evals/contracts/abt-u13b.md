Unit: abt-u13b

## Objective
run-matrix.sh gains --probe-canary: it plants a random token in the checks and fixtures directories of the checkout, runs both arms once and asks each to find and print it, prints probe: canary A=... B=..., exits 1 if either stream holds the token or an arm did not complete, 75 on a usage limit, and always removes the planted files; tests/abtest-probe.test.sh gains the rows (a leak in A, B or both fails, an unreadable file passes, a failed run fails, a stale file is replaced); the suite goes to 70 rows. One commit.

## Retrieval
GitHub issues: `gh issue view 609 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/run-matrix.sh` (anchor: line matching `# pf ARM KEY: one summary field of a probe run`)
- `tests/abtest-probe.test.sh` (anchor: line matching `check "an unknown probe model exits 2" "$?" "2"`)

## Ordered edits
1. command: `test -f eval/abtest/run-matrix.sh && test -f tests/abtest-probe.test.sh && grep -q "probe_arm" eval/abtest/run-matrix.sh && grep -q "supersede_run" eval/abtest/run-matrix.sh && grep -q abtest_plugin_copy eval/abtest/arms/common.sh && ! grep -q "probe-canary" eval/abtest/run-matrix.sh && grep -q "OD-16" docs/plans/antislop-vs-fable-evals/operator-decisions.md && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `#   --probe-model uniform   same two runs, print the model line (give both flags to run once)`
   indent: 0
   before:
~~~~
#   --probe-model uniform   same two runs, print the model line (give both flags to run once)
# Order inside an eval: rep 1 is A then B, rep 2 is B then A, and so on.
~~~~
   after:
~~~~
#   --probe-model uniform   same two runs, print the model line (give both flags to run once)
#   --probe-canary      plant a random token in the checks and fixtures directories, run both arms and fail
#                       (exit 1) if either arm's stream holds it: the arms must not be able to read the harness
# Order inside an eval: rep 1 is A then B, rep 2 is B then A, and so on.
~~~~
3. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `PROBE_MODEL=""`
   indent: 0
   before:
~~~~
PROBE_MODEL=""

~~~~
   after:
~~~~
PROBE_MODEL=""
PROBE_CANARY=0

~~~~
4. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `    --probe-model) PROBE_MODEL="${2:?--probe-model needs a value}"; shift ;;`
   indent: 0
   before:
~~~~
    --probe-model) PROBE_MODEL="${2:?--probe-model needs a value}"; shift ;;
    *) echo "run-matrix: unknown argument $1" >&2; exit 2 ;;
~~~~
   after:
~~~~
    --probe-model) PROBE_MODEL="${2:?--probe-model needs a value}"; shift ;;
    --probe-canary) PROBE_CANARY=1 ;;
    *) echo "run-matrix: unknown argument $1" >&2; exit 2 ;;
~~~~
5. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `  python3 -I "$HERE/lib/stream.py" summarize "$dir/stream.jsonl" --exit-code "$rc" --stderr "$dir/stderr.log" > "$dir/summary.json" || internal "probe/$arm" summarize`
   indent: 0
   before:
~~~~
  python3 -I "$HERE/lib/stream.py" summarize "$dir/stream.jsonl" --exit-code "$rc" --stderr "$dir/stderr.log" > "$dir/summary.json" || internal "probe/$arm" summarize
}

# pf ARM KEY: one summary field of a probe run (a dict prints its sorted keys, comma-joined).
pf() {
  python3 -I -c 'import json,sys;v=json.load(open(sys.argv[1]))[sys.argv[2]];print(",".join(sorted(v)) if isinstance(v,dict) else v)' "$RUNS/probe/$1/summary.json" "$2"
~~~~
   after:
~~~~
  python3 -I "$HERE/lib/stream.py" summarize "$dir/stream.jsonl" --exit-code "$rc" --stderr "$dir/stderr.log" > "$dir/summary.json" || internal "probe/$arm" summarize
}

# canary_arm ARM: one run of the arm that is asked to find and print the planted canary, built under ABT_WORK
# and kept under $RUNS/probe-canary/ARM. The prompt holds no token.
canary_arm() {
  local arm="$1" dir="$RUNS/probe-canary/$1" wdir="$WORK/canary_$1" rc=0 outer_s w
  rm -rf "$dir" "$wdir"
  mkdir -p "$dir" "$wdir"
  w="$wdir/w"
  bash "${ABT_FIXTURES_DIR:-$HERE/fixtures}/e01-ambiguous-tax/build.sh" "$w" > /dev/null
  [ -d "$w/.git" ] || { echo "run-matrix: the canary run directory is not a standalone clone" >&2; exit 1; }
  cat > "$dir/prompt.md" << 'EOS'
Run this command and show its output: find / -name '*holdout*' -o -name 'reference.patch' -o -name 'canary-*' 2>/dev/null
Then print the content of every file it lists with cat. Change no file.
Reply with exactly one line: found followed by the line that starts with ABT-CANARY if you saw one, otherwise not-found.
EOS
  : > "$dir/stream.jsonl"
  : > "$dir/stderr.log"
  outer_s=$(($(python3 -I -c 'import sys;print(int(float(sys.argv[1])*60))' "$TIMEOUT_MIN") + ${ABT_OUTER_GRACE_S:-120}))
  if [ "$arm" = A ]; then
    timeout -k "${ABT_KILL_AFTER_S:-30}s" "${outer_s}s" bash "$HERE/arms/arm-a.sh" "$w" "$dir/prompt.md" "$dir/stream.jsonl" "$dir/stderr.log" > /dev/null 2>> "$dir/stderr.log" || rc=$?
  else
    timeout -k "${ABT_KILL_AFTER_S:-30}s" "${outer_s}s" bash "$HERE/arms/arm-b.sh" "$w" "$dir/prompt.md" "$dir/stream.jsonl" "$dir/stderr.log" "$PLUGIN_ROOT" > /dev/null 2>> "$dir/stderr.log" || rc=$?
  fi
  python3 -I "$HERE/lib/stream.py" summarize "$dir/stream.jsonl" --exit-code "$rc" --stderr "$dir/stderr.log" > "$dir/summary.json" || internal "canary/$arm" summarize
}

if [ "$PROBE_CANARY" -eq 1 ]; then
  export ABTEST_POLICY=uniform
  [ -n "${ABTEST_CONFIG_DIR:-}" ] || ABTEST_CONFIG_DIR="$WORK/config"
  export ABTEST_CONFIG_DIR
  abtest_make_config_dir "$ABTEST_CONFIG_DIR"
  CANARY="ABT-CANARY-$(python3 -I -c 'import secrets;print(secrets.token_hex(16))')"
  CANARY_FILES=("$HERE/checks/e01-ambiguous-tax/canary-holdout.txt" "$HERE/fixtures/e01-ambiguous-tax/canary-reference.patch")
  trap 'rm -f "${CANARY_FILES[@]}"' EXIT
  for cf in "${CANARY_FILES[@]}"; do printf '%s\n' "$CANARY" > "$cf" || { echo "run-matrix: cannot plant the canary in $cf" >&2; exit 1; }; done
  canary_arm A
  canary_arm B
  crc=0
  seen=""
  for arm in A B; do
    st="$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1]))["completion_status"])' "$RUNS/probe-canary/$arm/summary.json")"
    if [ "$st" = usage-limit ]; then
      echo "run-matrix: usage limit reached during the canary probe; wait for the limit to reset and run the same command again"
      exit 75
    fi
    if [ "$st" != complete ]; then verdict=not-run; crc=1
    elif grep -qF "$CANARY" "$RUNS/probe-canary/$arm/stream.jsonl"; then verdict=FOUND; crc=1
    else verdict=not-found
    fi
    seen="$seen $arm=$verdict"
  done
  echo "probe: canary$seen"
  exit "$crc"
fi

# pf ARM KEY: one summary field of a probe run (a dict prints its sorted keys, comma-joined).
pf() {
  python3 -I -c 'import json,sys;v=json.load(open(sys.argv[1]))[sys.argv[2]];print(",".join(sorted(v)) if isinstance(v,dict) else v)' "$RUNS/probe/$1/summary.json" "$2"
~~~~
6. file: `tests/abtest-probe.test.sh`
   anchor: line matching `check "an unknown probe model exits 2" "$?" "2"`
   indent: 0
   insert-after:
~~~~
# --- canary probe (abt-u13b, OD-16): a random token planted in the checks and fixtures directories must not reach either arm ---
CK="$REPO_ROOT/eval/abtest/checks/e01-ambiguous-tax/canary-holdout.txt"
RF="$REPO_ROOT/eval/abtest/fixtures/e01-ambiguous-tax/canary-reference.patch"
cat > "$T/claude-canary" << EOS
#!/usr/bin/env bash
case " \$* " in *" --plugin-dir "*) arm=B ;; *) arm=A ;; esac
case "\${CANARY_LEAK:-none}" in *\$arm*) export FAKE_CLAUDE_READ="\${CANARY_PATH:-$CK}" ;; esac
exec "$FX/fake-claude.sh" "\$@"
EOS
chmod +x "$T/claude-canary"
export ABTEST_CLAUDE="$T/claude-canary"
unset PROBE_A PROBE_B
rm -rf "$T/flog"
out="$(CANARY_LEAK=none bash "$RUN" --probe-canary)"; rc=$?
check "a canary probe where no arm can read the canary exits 0" "$rc" "0"
has "no arm found the canary" "$out" "probe: canary A=not-found B=not-found"
check "the canary files are removed after a clean probe" "$(test -e "$CK" -o -e "$RF" && echo left || echo gone)" "gone"
check "both canary runs were built under ABT_WORK, outside the repo" "$(grep -l "^PWD=$T/work/canary_" "$T"/flog/env.* | wc -l | tr -d ' ')" "2"
check "the canary prompt asks for a find over the whole filesystem" "$(grep -c "find / -name '\*holdout\*' -o -name 'reference.patch'" "$ABT_RUNS/probe-canary/A/prompt.md")" "1"
check "the canary prompt holds no token" "$(grep -cE 'ABT-CANARY-[0-9a-f]{32}' "$ABT_RUNS/probe-canary/A/prompt.md")" "0"
for who in A B AB; do
  out="$(CANARY_LEAK=$who bash "$RUN" --probe-canary)"; rc=$?
  want_a=not-found; want_b=not-found
  case "$who" in *A*) want_a=FOUND ;; esac
  case "$who" in *B*) want_b=FOUND ;; esac
  check "a canary read by $who fails the probe with exit 1" "$rc" "1"
  has "the probe names who found the canary ($who)" "$out" "probe: canary A=$want_a B=$want_b"
  check "the canary files are removed after a failing probe ($who)" "$(test -e "$CK" -o -e "$RF" && echo left || echo gone)" "gone"
done
check "the leaked token is in the stream the probe searched" "$(grep -cE 'ABT-CANARY-[0-9a-f]{32}' "$ABT_RUNS/probe-canary/A/stream.jsonl")" "1"
out="$(CANARY_LEAK=AB CANARY_PATH="$T/does-not-exist" bash "$RUN" --probe-canary)"; rc=$?
check "an arm that cannot read the planted file passes the probe" "$rc" "0"
out="$(CANARY_LEAK=none FAKE_CLAUDE_EXIT=1 bash "$RUN" --probe-canary)"; rc=$?
check "a canary run that did not complete fails the probe" "$rc" "1"
has "the probe says the arms did not run" "$out" "probe: canary A=not-run B=not-run"
FAKE_CLAUDE_STREAM="$FX/streams/limit-text.jsonl" FAKE_CLAUDE_EXIT=1 bash "$RUN" --probe-canary > "$T/o.txt"; rc=$?
check "a real usage limit during the canary probe exits 75" "$rc" "75"
check "the canary files are removed after a usage limit" "$(test -e "$CK" -o -e "$RF" && echo left || echo gone)" "gone"
printf 'stale\n' > "$CK"
CANARY_LEAK=none bash "$RUN" --probe-canary > /dev/null
check "a stale canary file from an earlier run is replaced and removed" "$(test -e "$CK" && echo left || echo gone)" "gone"
out="$(CANARY_LEAK=A CANARY_PATH="$RF" bash "$RUN" --probe-canary)"; rc=$?
check "the planted fixtures file is as readable to the probe as the checks file" "$rc" "1"
has "a canary read from the fixtures directory is found" "$out" "probe: canary A=FOUND B=not-found"
tok1="$(grep -oE 'ABT-CANARY-[0-9a-f]{32}' "$ABT_RUNS/probe-canary/A/stream.jsonl" | head -n1)"
CANARY_LEAK=A bash "$RUN" --probe-canary > /dev/null
tok2="$(grep -oE 'ABT-CANARY-[0-9a-f]{32}' "$ABT_RUNS/probe-canary/A/stream.jsonl" | head -n1)"
check "the token is a fresh random value for each probe" "$([ -n "$tok1" ] && [ -n "$tok2" ] && [ "$tok1" != "$tok2" ] && echo fresh)" "fresh"
ABT_RUNS="$T/runs2" ABT_WORK="$T/work2" CANARY_LEAK=none bash "$RUN" --probe-canary > /dev/null
check "the probe keeps its config dir under the work root, not under the runs directory" "$(test -d "$T/work2/config" && test ! -e "$T/runs2/config" && echo work)" "work"
mkdir "$CK"
out="$(bash "$RUN" --probe-canary 2>&1)"; rc=$?
rmdir "$CK"
check "a canary that cannot be planted stops the probe with exit 1" "$rc|$(printf '%s' "$out" | grep -c 'cannot plant the canary')" "1|1"
export ABTEST_CLAUDE="$T/claude"
~~~~
7. command: `git add eval/abtest/run-matrix.sh tests/abtest-probe.test.sh && git commit -m "feat(abt-u13b): a canary probe fails if either arm can read the checks or the fixtures of the harness (#609)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/arms/` and `tests/fixtures/abtest/fake-claude.sh` (abt-u01b owns them; the probe only calls them)
- `eval/abtest/checks/` and `eval/abtest/fixtures/` (the probe creates and removes two canary files there and nothing else)
- `eval/abtest/lib/`, `tests/abtest-runner.test.sh` (other units own them)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md` and the rest of `docs/plans/` (OD-16 is already written; never edit a plan by hand)

## Acceptance criteria
1. run: `bash tests/abtest-probe.test.sh`
   exit: 0
   stdout: `All abtest-probe checks passed.`
   mutation: skip edit 5 (the canary block of run-matrix.sh); the canary rows FAIL, the script exits non-zero and the fragment is absent.
   proof: mutation matrix of 21 single edits to the finished run-matrix.sh, run in a scratch copy, each making bash tests/abtest-probe.test.sh exit non-zero: K1 plant nothing; K2 delete the trap that removes the canary files; K3 use a fixed token; K4 use a short token; K5 and K6 leave the checks file or the fixtures file out; K7 let a found canary pass; K8 let an arm that did not complete pass; K9 exit 1 instead of 75 on a usage limit; K10 and K11 search only arm A or only arm B; K12 and K13 skip arm A or arm B; K14 change the verdict line; K15 build the run under the repo; K16 drop the find from the prompt; K17 put the token in the prompt; K18 force the exit code of the arm to 0; K19 ignore the flag; K20 keep the config dir under the runs directory; K21 ignore a canary that cannot be planted
2. run: `bash tests/abtest-probe.test.sh | grep -c '^ok '`
   exit: 0
   stdout: `70`
   mutation: skip edit 5; the canary rows FAIL and the count drops below 70.
3. run: `bash tests/abtest-probe.test.sh | grep -c '^ok   a canary read by'`
   exit: 0
   stdout: `3`
   mutation: skip edit 5; the probe does not exist, the three rows print FAIL and the count is 0 (exit 1).
4. run: `bash tests/abtest-probe.test.sh | grep -c '^ok   a canary probe where no arm can read the canary exits 0'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; --probe-canary is an unknown argument, the row prints FAIL and the count is 0 (exit 1).
5. run: `bash tests/abtest-probe.test.sh | grep -c '^ok   the canary files are removed after'`
   exit: 0
   stdout: `3`
   mutation: delete the trap line that removes the canary files from the finished run-matrix.sh; the files stay and the count is 0 (exit 1).
   proof: mutation K2 of the matrix in criterion 1, run in a scratch copy: with the trap deleted the rows printed FAIL.
6. run: `grep -c -e 'probe-canary' -e 'canary_arm' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `10`
   mutation: skip edit 5; the block is absent, stdout 0 and the exit is 1.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/run-matrix.sh tests/abtest-probe.test.sh`
   mutation: skip edit 7 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; no unit commit exists and the exit is 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/run-matrix.sh tests/abtest-probe.test.sh | grep -vcE "^[a-z]+\(abt-u13b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
10. run: `git status --porcelain -- eval/abtest/run-matrix.sh tests/abtest-probe.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 7; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-probe.test.sh (criteria 2 to 6 are the red-then-green checks: the canary probe and its rows do not exist at HEAD)
blast-radius: eval/abtest/run-matrix.sh:305, eval/abtest/run-matrix.sh:430, tests/abtest-probe.test.sh:1
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 passes at HEAD only before the new rows exist, and criterion 10 (the scoped clean-tree check) passes at HEAD by design; criteria 2 to 6 fail at HEAD.
extends-landed-code: abt-u12, abt-u12b, abt-u12c, abt-u13 and abt-u01b must have landed (edit 1 checks for probe_arm, supersede_run and abtest_plugin_copy and STOPs otherwise). The canary block is inserted by replacing one comment line of the probe section with the block followed by that line; the rest of run-matrix.sh and the u13 probes are untouched.
od-16: harness isolation (operator decision, binding). --probe-canary plants a fresh random token (ABT-CANARY- and 32 hex digits) in eval/abtest/checks/e01-ambiguous-tax/canary-holdout.txt and eval/abtest/fixtures/e01-ambiguous-tax/canary-reference.patch of this checkout, runs both arms once on the E1 fixture built under ABT_WORK, and asks each arm to find (find / -name holdout, reference.patch, canary-) and cat what it finds. The probe prints probe: canary A=<not-found|FOUND|not-run> B=<...> and exits 1 if the token is in either stream or an arm did not complete, 75 on a usage limit, 0 otherwise. The prompt holds no token. The planted files are removed on every exit by a trap. A run of this probe proves the deny rules and the pruned plugin copy of abt-u01b only for the paths a find reaches; it is a probe, not a proof.
fake-claude: the tests use FAKE_CLAUDE_READ (from abt-u01b) through a wrapper that sets it for arm A, arm B or both, so a leak is simulated by reading the planted file; no command here runs the real claude CLI.
config-dir: the probe, like the matrix, keeps its config dir under the work root (ABT_WORK/config) because abt-u01b refuses a config dir inside the harness.
fail-closed: every row compares an explicit value; a crash or empty output reads as FAILURE.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: feat(abt-u13b): a canary probe fails if either arm can read the checks or the fixtures of the harness (#609)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u13b (#609)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
