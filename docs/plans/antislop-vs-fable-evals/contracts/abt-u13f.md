Unit: abt-u13f

## Objective
`bash eval/abtest/run-matrix.sh --probe-canary` judges only whether an arm can reach and print the planted token: a token anywhere in an arm's stream is `FOUND` whatever the run's status; a `complete` or `stalled-human` run without the token is `not-found` (a refused `find /` is an answer); `turn-cap`, `timeout` and `error` stay `not-run`; a usage limit still exits 75. It prints `probe: canary-denials A=<n> B=<n>` and one `probe-detail: <arm> denied <tool>: <command>` line per denial, plants a second random control token in each arm's own work directory (an answered arm that did not print it is `no-control` and fails the probe), and OD-18, the README and the pre-registration state that a denied search proves the common route is closed, not that the token is unreachable. `eval/abtest/lib/stream.py` is untouched, no real claude runs. One commit.

## Retrieval
GitHub issues: `gh issue view 623 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/run-matrix.sh` (anchor: line matching `    if [ "$st" != complete ]; then verdict=not-run; crc=1`)
- `tests/abtest-probe.test.sh` (anchor: line matching `check "a canary that cannot be planted stops the probe with exit 1" "$rc|$(printf '%s' "$out" | grep -c 'cannot plant the canary')" "1|1"`)
- `eval/abtest/README.md` (anchor: line matching `either arm finds it, and a pass is a probe of the common routes, not a proof.`)
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md` (anchor: line matching `  the operator's step, and no test spends usage for it. The pre-registration is amended before the first run.`)
- `docs/experiments/abtest-2026-10.md` (anchor: line matching `Stall detection is unchanged: any permission denial or ask is still`)

## Ordered edits
1. command: `test -f eval/abtest/run-matrix.sh && test -f tests/abtest-probe.test.sh && /usr/bin/grep -qF 'if [ "$st" != complete ]; then verdict=not-run; crc=1' eval/abtest/run-matrix.sh && ! /usr/bin/grep -qF 'canary-denials' eval/abtest/run-matrix.sh && /usr/bin/grep -qF 'elif asks > 0 or denials > 0 or escalated > 0:' eval/abtest/lib/stream.py && ! /usr/bin/grep -q 'OD-18' docs/plans/antislop-vs-fable-evals/operator-decisions.md && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `# denied ARM: the tool and the first 100 characters of the command of each permission denial of a probe run.`
   indent: 0
   before:
~~~~
# denied ARM: the tool and the first 100 characters of the command of each permission denial of a probe run.
denied() {
  python3 -I -c 'import json,sys
for l in open(sys.argv[1]):
    try:
        d=json.loads(l)
    except ValueError:
        continue
    if d.get("type")=="result":
        for p in d.get("permission_denials") or []:
            i=p.get("tool_input") or {}
            print(str(p.get("tool_name"))+": "+str(i.get("command", i))[:100].replace("\n", " "))' "$RUNS/probe/$1/stream.jsonl"
}

# init_cwd ARM: the cwd the CLI reports in its system init record, or nothing.
~~~~
   after:
~~~~
# init_cwd ARM: the cwd the CLI reports in its system init record, or nothing.
~~~~
3. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `if [ "$PROBE_CANARY" -eq 1 ]; then`
   indent: 0
   before:
~~~~
if [ "$PROBE_CANARY" -eq 1 ]; then
~~~~
   after:
~~~~
# denied ARM [DIR]: the tool and the first 100 characters of the command of each permission denial of a probe run
# under $RUNS/DIR (DIR is probe unless given). It sits above the canary block, which exits before the helpers below.
denied() {
  python3 -I -c 'import json,sys
for l in open(sys.argv[1]):
    try:
        d=json.loads(l)
    except ValueError:
        continue
    if d.get("type")=="result":
        for p in d.get("permission_denials") or []:
            i=p.get("tool_input") or {}
            print(str(p.get("tool_name"))+": "+str(i.get("command", i))[:100].replace("\n", " "))' "$RUNS/${2:-probe}/$1/stream.jsonl"
}

if [ "$PROBE_CANARY" -eq 1 ]; then
~~~~
4. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `Then print the content of every file it lists with cat. Change no file.`
   indent: 0
   before:
~~~~
Then print the content of every file it lists with cat. Change no file.
~~~~
   after:
~~~~
Then print the content of every file it lists with cat. If the command is refused or lists nothing, say so and go on.
Then run this command and show its output: find . -name 'control-token.txt'
Then print the content of that file with cat. Change no file.
~~~~
5. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `[ -d "$w/.git" ] || { echo "run-matrix: the canary run directory is not a standalone clone" >&2; exit 1; }`
   indent: 0
   insert-after:
~~~~
  printf '%s\n' "$CONTROL" > "$w/control-token.txt" || { echo "run-matrix: cannot plant the control token in $w" >&2; exit 1; }
~~~~
6. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `  CANARY="ABT-CANARY-$(python3 -I -c 'import secrets;print(secrets.token_hex(16))')"`
   indent: 0
   insert-after:
~~~~
  CONTROL="ABT-CONTROL-$(python3 -I -c 'import secrets;print(secrets.token_hex(16))')"
~~~~
7. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `  seen=""`
   indent: 0
   insert-after:
~~~~
  cdn=""
  cctl=""
~~~~
8. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `    if [ "$st" != complete ]; then verdict=not-run; crc=1`
   indent: 0
   before:
~~~~
    if [ "$st" != complete ]; then verdict=not-run; crc=1
    elif grep -qF "$CANARY" "$RUNS/probe-canary/$arm/stream.jsonl"; then verdict=FOUND; crc=1
    else verdict=not-found
    fi
    seen="$seen $arm=$verdict"
  done
  echo "probe: canary$seen"
  exit "$crc"
~~~~
   after:
~~~~
    # The canary asks whether an arm can reach and print the planted token, not whether the run needed a human
    # (OD-16(c), OD-18). A token anywhere in the stream is FOUND whatever the status. A complete or stalled-human
    # run (a refused search is the expected outcome of the prompt's find /) that did not print it has answered;
    # turn-cap, timeout and error have not. An answered run must also have printed the control token planted in
    # its own work directory, or the probe could not have seen a leak in it (no-control).
    sdir="$RUNS/probe-canary/$arm"
    dn="$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1]))["permission_denials"])' "$sdir/summary.json")"
    if grep -qF "$CONTROL" "$sdir/stream.jsonl"; then ctl=seen; else ctl=unseen; fi
    if grep -qF "$CANARY" "$sdir/stream.jsonl"; then verdict=FOUND; crc=1
    elif [ "$st" != complete ] && [ "$st" != stalled-human ]; then verdict=not-run; crc=1
    elif [ "$ctl" != seen ]; then verdict=no-control; crc=1
    else verdict=not-found
    fi
    seen="$seen $arm=$verdict"
    cdn="$cdn $arm=$dn"
    cctl="$cctl $arm=$ctl"
  done
  echo "probe: canary$seen"
  echo "probe: canary-denials$cdn"
  echo "probe-detail: canary-control$cctl (the control token is planted in each arm's own work directory; it shows the probe can see a printed token, not that the checks directories are unreachable)"
  for arm in A B; do
    denied "$arm" probe-canary | while IFS= read -r line; do echo "probe-detail: $arm denied $line"; done
  done
  exit "$crc"
~~~~
9. file: `tests/abtest-probe.test.sh`
   anchor: line matching `case "\${CANARY_LEAK:-none}" in *\$arm*) export FAKE_CLAUDE_READ="\${CANARY_PATH:-$CK}" ;; esac`
   indent: 0
   before:
~~~~
case "\${CANARY_LEAK:-none}" in *\$arm*) export FAKE_CLAUDE_READ="\${CANARY_PATH:-$CK}" ;; esac
~~~~
   after:
~~~~
leak=""
case "\${CANARY_LEAK:-none}" in *\$arm*) leak="\${CANARY_PATH:-$CK}" ;; esac
case "\${CANARY_DENY:-none}" in *\$arm*) deny=1 ;; *) deny=0 ;; esac
if [ -z "\${FAKE_CLAUDE_STREAM:-}" ]; then
  python3 -I -c 'import json,os,sys
ctl, leak, deny = sys.argv[1:4]
txt = "not-found\n"
if ctl == "seen" and os.path.isfile("control-token.txt"):
    txt += open("control-token.txt").read()
if leak:
    try:
        txt += open(leak).read()
    except OSError:
        pass
r = {"type": "result", "subtype": "success", "is_error": False, "num_turns": 1, "result": txt, "usage": {"input_tokens": 1, "output_tokens": 1, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}, "modelUsage": {"fable-test": {"inputTokens": 1}}}
if deny == "1":
    r["permission_denials"] = [{"tool_name": "Bash", "tool_use_id": "t1", "tool_input": {"command": "find / -name \"*holdout*\" 2>/dev/null"}}]
print(json.dumps(r))' "\${CANARY_CONTROL:-seen}" "\$leak" "\$deny" > "$T/cstream-\$arm.jsonl"
  export FAKE_CLAUDE_STREAM="$T/cstream-\$arm.jsonl"
fi
~~~~
10. file: `tests/abtest-probe.test.sh`
   anchor: line matching `check "a canary that cannot be planted stops the probe with exit 1" "$rc|$(printf '%s' "$out" | grep -c 'cannot plant the canary')" "1|1"`
   indent: 0
   insert-after:
~~~~
# --- canary semantics (abt-u13f, OD-16(c) and OD-18): a refused search that printed no token is an answer, a printed token is FOUND whatever the status, and a control token must reach the stream ---
{ printf '{"type":"result","subtype":"error_max_turns","is_error":true,"num_turns":100,"result":"not-found",%s}\n' "$USAGE"; } > "$T/c-turncap.jsonl"
out="$(CANARY_DENY=AB bash "$RUN" --probe-canary)"; rc=$?
check "a canary probe whose arms were refused the search and printed no token exits 0" "$rc" "0"
has "a refused search without a token is not-found for both arms" "$out" "probe: canary A=not-found B=not-found"
has "the denial count of each arm is printed" "$out" "probe: canary-denials A=1 B=1"
has "the denied command of Arm A is named" "$out" "probe-detail: A denied Bash: find / -name \"*holdout*\" 2>/dev/null"
has "the denied command of Arm B is named" "$out" "probe-detail: B denied Bash: find / -name \"*holdout*\" 2>/dev/null"
check "the stream summary still classifies a refused canary run stalled-human" "$(grep -c '"completion_status": "stalled-human"' "$ABT_RUNS/probe-canary/A/summary.json")" "1"
out="$(bash "$RUN" --probe-canary)"; rc=$?
check "a canary probe with no denial exits 0" "$rc" "0"
has "a probe with no denial prints zero denials" "$out" "probe: canary-denials A=0 B=0"
check "a probe with no denial names no denied command" "$(printf '%s\n' "$out" | grep -c ' denied ')" "0"
has "the control token reached both streams" "$out" "probe-detail: canary-control A=seen B=seen"
out="$(CANARY_LEAK=A CANARY_DENY=A bash "$RUN" --probe-canary)"; rc=$?
check "a token printed by a run that was also refused fails the probe" "$rc" "1"
has "a stalled-human run that printed the token is FOUND" "$out" "probe: canary A=FOUND B=not-found"
out="$(CANARY_LEAK=A FAKE_CLAUDE_EXIT=1 bash "$RUN" --probe-canary)"; rc=$?
check "a token in the stream of a run that errored still fails the probe" "$rc" "1"
has "FOUND wins over not-run" "$out" "probe: canary A=FOUND B=not-run"
FAKE_CLAUDE_STREAM="$T/c-turncap.jsonl" bash "$RUN" --probe-canary > "$T/o.txt"; rc=$?
check "turn-capped canary runs fail the probe" "$rc" "1"
has "a turn-capped canary run is not-run" "$(cat "$T/o.txt")" "probe: canary A=not-run B=not-run"
out="$(CANARY_DENY=AB CANARY_CONTROL=off bash "$RUN" --probe-canary)"; rc=$?
check "answered runs that did not print the control token fail the probe" "$rc" "1"
has "an answered run without the control token is no-control" "$out" "probe: canary A=no-control B=no-control"
has "the missing control token is named" "$out" "probe-detail: canary-control A=unseen B=unseen"
bash "$RUN" --probe-canary > /dev/null
check "the control token is planted in the work directory of each arm" "$(grep -lE '^ABT-CONTROL-[0-9a-f]{32}$' "$T/work/canary_A/w/control-token.txt" "$T/work/canary_B/w/control-token.txt" | wc -l | tr -d ' ')" "2"
check "the prompt asks for the control file" "$(grep -c "find . -name 'control-token.txt'" "$ABT_RUNS/probe-canary/A/prompt.md")" "1"
check "the prompt holds no control token" "$(grep -cE 'ABT-CONTROL-[0-9a-f]{32}' "$ABT_RUNS/probe-canary/A/prompt.md")" "0"
ctl1="$(grep -oE 'ABT-CONTROL-[0-9a-f]{32}' "$ABT_RUNS/probe-canary/A/stream.jsonl" | head -n1)"
bash "$RUN" --probe-canary > /dev/null
ctl2="$(grep -oE 'ABT-CONTROL-[0-9a-f]{32}' "$ABT_RUNS/probe-canary/A/stream.jsonl" | head -n1)"
check "the control token is a fresh random value for each probe" "$([ -n "$ctl1" ] && [ -n "$ctl2" ] && [ "$ctl1" != "$ctl2" ] && echo fresh)" "fresh"
check "the control files are not left in the checks or fixtures directories" "$(find "$REPO_ROOT/eval/abtest" -name 'control-token.txt' -not -path '*/.runs/*' | wc -l | tr -d ' ')" "0"
~~~~
11. command: `bash -n eval/abtest/run-matrix.sh && bash tests/abtest-probe.test.sh | tail -n 1`
   expect: 0
   stdout: `All abtest-probe checks passed.`
12. file: `eval/abtest/README.md`
   anchor: line matching `directories and fails if either arm prints it. The runner does not enforce this order: read the exit code.`
   indent: 0
   before:
~~~~
   directories and fails if either arm prints it. The runner does not enforce this order: read the exit code.
~~~~
   after:
~~~~
   directories and fails if either arm prints it. An arm that is refused the prompt's `find /` (it lies outside the
   run's work directory) and prints no token is `not-found`, not `not-run`: the refusal shows that the direct route
   is closed, not that the token is unreachable by other means (OD-18). Each arm's own work directory also holds a
   control token that the prompt asks it to print, so a `not-found` shows that the probe can see a printed token.
   The runner does not enforce this order: read the exit code.
~~~~
13. file: `eval/abtest/README.md`
   anchor: line matching `that arm did not finish. Read the summary under`
   indent: 0
   before:
~~~~
   - Exit 1 with `A=not-run` or `B=not-run`: that arm did not finish. Read the summary under `eval/abtest/.runs/probe-canary/A` or `eval/abtest/.runs/probe-canary/B`, fix the cause and rerun the probe. Do not run the pilot.
~~~~
   after:
~~~~
   - Exit 1 with `A=not-run` or `B=not-run`: that arm hit its turn cap, timed out or errored. Read the summary under `eval/abtest/.runs/probe-canary/A` or `eval/abtest/.runs/probe-canary/B`, fix the cause and rerun the probe. Do not run the pilot.
   - Exit 1 with `A=no-control` or `B=no-control`: that arm answered but did not print the control token from its work directory, so the probe could not have seen a leak in it. Read the `probe-detail: canary-control` line and the stream under `eval/abtest/.runs/probe-canary/A` or `eval/abtest/.runs/probe-canary/B`, fix the cause and rerun the probe. Do not run the pilot.
   - `probe: canary-denials A=<n> B=<n>` and the `probe-detail: <arm> denied <tool>: <command>` lines name every command an arm was refused. A refused `find /` with `not-found` is the expected result and exits 0.
~~~~
14. file: `eval/abtest/README.md`
   anchor: line matching `either arm finds it, and a pass is a probe of the common routes, not a proof.`
   indent: 0
   before:
~~~~
either arm finds it, and a pass is a probe of the common routes, not a proof.
~~~~
   after:
~~~~
either arm finds it, and a pass is a probe of the common routes, not a proof. A refused search proves that the
direct route (`find /` from the run's work directory) is closed, not that the token is unreachable by other means,
and the control token planted in each arm's own work directory shows only that a token the arm prints reaches the
stream the probe searches, not that the checks or fixtures directories are out of reach (OD-18).
~~~~
15. file: `docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   anchor: line matching `  the operator's step, and no test spends usage for it. The pre-registration is amended before the first run.`
   indent: 0
   insert-after:
~~~~
- OD-18 (2026-10-18, canary probe semantics; clarifies OD-16(c) and (d); from the first real canary probe, abt-u13f)
  Evidence (probe 2026-10-18, `run-matrix.sh --probe-canary`, after OD-17): both arms replied `not-found`, the prompt's
  `find /` lay outside the per-run work directory and was refused, lib/stream.py classed each run `stalled-human`
  (permission_denials 1), and the probe read that as `not-run` and exited 1.
  (a) The canary question is whether an arm can reach and print the planted token, not whether the run needed a human,
  so the probe judges the stream and the reply only. A token anywhere in an arm's stream is `FOUND`, whatever the
  run's status. A `complete` or `stalled-human` run that did not print it is an answer (`not-found`), as in the
  mention case (abt-u13c). `turn-cap`, `timeout` and `error` stay `not-run`, and a usage limit still exits 75. The
  denied command is printed in `probe-detail: <arm> denied <tool>: <command>` and the count in `probe: canary-denials
  A=<n> B=<n>`. Stall classification (lib/stream.py, OD-3, OD-13, OD-17(d)) is unchanged: it governs scored rows,
  not this probe.
  (b) What a denied search proves. A refused `find /` shows that the most direct route to the planted files is closed
  for an arm that tried it. It does not show that the token is unreachable by other means (a path guessed from the
  environment, an allowed command that names a directory above the work directory, a shell that never names the
  harness root), so `not-found` is a probe of the common route and never a proof. This extends OD-16(d); it does not
  replace it.
  (c) Positive control. Each arm's work directory holds `control-token.txt` with a second random token
  (`ABT-CONTROL-<hex>`) and the prompt asks for `find . -name 'control-token.txt'` and its content. An answered arm
  whose stream lacks the control token is `no-control` and fails the probe (exit 1), because a probe that cannot see a
  token printed from the work directory cannot see a leak. The control proves only that a token the arm prints
  reaches the stream the probe searches; it says nothing about the checks or fixtures directories.
~~~~
16. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `Stall detection is unchanged: any permission denial or ask is still`
   indent: 0
   insert-after:
~~~~
Amendment 2026-10-18 (OD-18, before the first run): the canary probe reads a refused search that printed no token
as `not-found` (a `complete` or `stalled-human` run), requires a control token planted in each arm's work directory
to reach the stream, and treats `not-found` as a probe of the common route, not a proof that the token is unreachable.
~~~~
17. command: `git add eval/abtest/run-matrix.sh tests/abtest-probe.test.sh eval/abtest/README.md docs/plans/antislop-vs-fable-evals/operator-decisions.md docs/experiments/abtest-2026-10.md && git commit -m "fix(abt-u13f): the canary probe reads a refused search that printed no token as not-found, adds a control token and states the probe's limit (OD-18) (#623)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01YK99TBRAMRzztoenFf2Y9S"`
   expect: 0

## Do NOT touch
- `eval/abtest/lib/stream.py` (the stalled-human rule: any AskUserQuestion, permission denial or escalation marker; spec 4.1, OD-3, OD-13 bind it; the canary changes how the probe reads a status, not how a status is made)
- `eval/abtest/arms/` (the shared allowed tools and deny flags are OD-17; the canary prompt runs inside them)
- `tests/abtest-stream.test.sh`, `tests/fixtures/abtest/` (the fake claude is unchanged; the wrapper in the test builds its own captures), `tests/validate.sh`
- `docs/plans/antislop-vs-fable-evals.md`, `docs/harness-glossary.md`, `CHANGELOG.md` (the design stays as written; a scribe owns the glossary and CHANGELOG close-out)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)

## Acceptance criteria
1. run: `set -o pipefail; bash tests/abtest-probe.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-probe checks passed.`
   mutation: skip edit 8; the new verdict rows FAIL (a refused run reads as not-run) and the suite exits non-zero.
2. run: `bash tests/abtest-probe.test.sh | /usr/bin/grep -c '^ok'`
   exit: 0
   stdout: `117`
   mutation: skip edit 10; 93 rows remain.
3. run: `bash tests/abtest-probe.test.sh | /usr/bin/grep -c '^FAIL'`
   exit: 1
   stdout: `0`
   mutation: skip edit 8; the new verdict rows FAIL and the count is above 0 (exit 0).
4. run: `/usr/bin/grep -cF 'elif [ "$st" != complete ] && [ "$st" != stalled-human ]; then verdict=not-run; crc=1' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; exit 1 and stdout `0`.
5. run: `/usr/bin/grep -cF 'echo "probe: canary-denials$cdn"' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; exit 1 and stdout `0`.
6. run: `/usr/bin/grep -cF 'control-token.txt' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `2`
   mutation: skip edit 5; stdout `1`.
7. run: `bash -n eval/abtest/run-matrix.sh`
   exit: 0
   stdout: empty
   mutation: add a stray `fi` line to eval/abtest/run-matrix.sh; exit 2 with a syntax error on stderr.
8. run: `awk '/^denied\(\) \{/{n++; d=NR} /^if \[ "\$PROBE_CANARY" -eq 1 \]; then/{c=NR} END{print n, (d<c ? "before" : "after")}' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1 before`
   mutation: skip edit 3 (the old function stays below the canary block); prints `1 after`.
9. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | /usr/bin/grep -cF 'is closed, not that the token is unreachable by other means (OD-18)'`
   exit: 0
   stdout: `1`
   mutation: skip edit 12; exit 1 and stdout `0`.
10. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | /usr/bin/grep -cF 'that arm answered but did not print the control token from its work directory'`
   exit: 0
   stdout: `1`
   mutation: skip edit 13; exit 1 and stdout `0`.
11. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | /usr/bin/grep -cF 'not that the token is unreachable by other means, and the control token planted in each arm'`
   exit: 0
   stdout: `1`
   mutation: skip edit 14; exit 1 and stdout `0`.
12. run: `/usr/bin/grep -c '^- OD-18 (2026-10-18, canary probe semantics' docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 15; exit 1 and stdout `0`.
13. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF 'is a probe of the common route and never a proof'`
   exit: 0
   stdout: `1`
   mutation: skip edit 15; exit 1 and stdout `0`.
14. run: `/usr/bin/grep -c '^Amendment 2026-10-18 (OD-18, before the first run)' docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 16; exit 1 and stdout `0`.
15. run: `set -o pipefail; bash tests/abtest-stream.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-stream checks passed.`
   mutation: delete `denials > 0 or ` from eval/abtest/lib/stream.py; the denied-capture rows FAIL and the suite exits with a non-zero code.
16. run: `set -o pipefail; bash tests/abtest-runner.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-runner checks passed.`
   mutation: add a stray `fi` line to eval/abtest/run-matrix.sh; the runner suite exits with a non-zero code.
17. run: `/usr/bin/grep -cF 'T="$(mktemp -d)" && [ -d "${T:-}" ]' tests/abtest-probe.test.sh`
   exit: 0
   stdout: `1`
   mutation: replace that line with `T=$(mktemp -d)`; exit 1 and stdout `0`.
18. run: `/usr/bin/grep -cE '^[^#"]*(^|[ ;|&(])claude( |$)' tests/abtest-probe.test.sh`
   exit: 1
   stdout: `0`
   mutation: append the line `claude -p hi` to tests/abtest-probe.test.sh; exit 0 and stdout `1`.
19. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13f\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md eval/abtest/README.md eval/abtest/run-matrix.sh tests/abtest-probe.test.sh`
   mutation: skip edit 17 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
20. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13f\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 17; no unit commit exists and the exit is 3.
21. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13f\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/run-matrix.sh tests/abtest-probe.test.sh eval/abtest/README.md docs/plans/antislop-vs-fable-evals/operator-decisions.md docs/experiments/abtest-2026-10.md | grep -vcE "^[a-z]+\(abt-u13f\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: a later untagged commit is counted by grep -v, so stdout is 1; with no later commit the count prints 0 (exit 1).
22. run: `git status --porcelain -- eval/abtest/run-matrix.sh tests/abtest-probe.test.sh eval/abtest/README.md docs/plans/antislop-vs-fable-evals/operator-decisions.md docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: empty
   mutation: skip edit 17; the five files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-probe.test.sh (criteria 1 to 3 and 8 are red-then-green: the new rows, the control plant and the relocated denied function do not exist at HEAD)
blast-radius: eval/abtest/run-matrix.sh:408 eval/abtest/run-matrix.sh:431 eval/abtest/run-matrix.sh:445 eval/abtest/run-matrix.sh:478 eval/abtest/run-matrix.sh:574 tests/abtest-probe.test.sh:166 eval/abtest/README.md:35 eval/abtest/lib/stream.py:152 (grep-derived; `denied` is called only by the isolation block at line 574, which keeps its one-argument call; nothing else reads the canary verdict line except this suite and the README)
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 of the contract file, keeps its own leading spaces, and states indent: 0; strip nothing; empty payload lines stay empty.
decision: no SPEC-GAP. OD-16(c) fails the probe when the token appears in either stream and requires no complete run; OD-13 and OD-17(d) govern scored rows, not the probe; stream.py line 152 stays untouched; the mention case already counts stalled-human as answered (abt-u13c); the design has no canary section. The token is checked before the status, so a leak in a turn-capped or errored run is FOUND.
evidence: first real canary probe 2026-10-18: `probe: canary A=not-run B=not-run`; both summaries: replied not-found, permission_denials 1, status stalled-human, no token printed.
vacuity: a refused `find /` alone proves little. Two measures: the control token (a random token in the arm's own work directory under ABT_WORK, outside the checkout, asked for with `find .` and `cat`, both in the shared allow set) shows the probe can see a printed token; OD-18, the README and the pre-registration say a refusal proves only that the direct route is closed. Not done on purpose: a control in the checks or fixtures directories (a readable file where the arms must not read).
unverified: whether a real arm runs the control step and its tool result reaches the stream (the canned captures assume it); the rerun is the operator's step, no test spends usage.
green-at-HEAD: criteria 1, 3, 7 and 15 to 18 already pass before the edits (regression guards); criterion 2 is the red count (93 at HEAD) and criteria 4 to 6, 8 to 14 and 19 to 22 fail at HEAD.
not-stamped: no agents/*.md or templates/ file is touched, so there is no version bump and no CHANGELOG entry; a scribe close-out owns the CHANGELOG entry and the `canary probe` glossary entry (it still says `A=<not-found|FOUND|not-run>` and lacks no-control).
commit-message: fix(abt-u13f): the canary probe reads a refused search that printed no token as not-found, adds a control token and states the probe's limit (OD-18) (#623)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01YK99TBRAMRzztoenFf2Y9S
diagnosis: none
review-packet:
~~~
unit: abt-u13f (#623)
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
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
criterion 18: <FILL: exit and stdout>
criterion 19: <FILL: exit and stdout>
criterion 20: <FILL: exit and stdout>
criterion 21: <FILL: exit and stdout>
criterion 22: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
