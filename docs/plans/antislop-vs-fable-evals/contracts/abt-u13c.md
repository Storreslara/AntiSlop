Unit: abt-u13c

## Objective
The isolation probe stops reading a correct answer that needed a human as a mention-case failure: `run-matrix.sh --probe-isolation` counts `complete` and `stalled-human` as answered in the mention case, prints `probe: stall-signals A=<n> B=<n>` and one `probe-detail: <arm> denied <tool>: <command>` line per permission denial, and still exits 1 when either arm has a stall signal; `--probe-model uniform` prints `probe-detail: A other-models=... B other-models=...` and keeps its pass rule (fable in each arm). `eval/abtest/lib/stream.py` is untouched. `tests/abtest-probe.test.sh` goes from 70 to 93 rows. One commit.

## Retrieval
GitHub issues: `gh issue view 620 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/run-matrix.sh` (anchor: line matching `[ "$(pf "$arm" completion_status)" = complete ] || mention=failed`)
- `tests/abtest-probe.test.sh` (anchor: line matching `check "an unknown probe model exits 2" "$?" "2"`)

## Ordered edits
1. command: `test -f eval/abtest/run-matrix.sh && test -f tests/abtest-probe.test.sh && /usr/bin/grep -qF 'mention=failed' eval/abtest/run-matrix.sh && ! /usr/bin/grep -qF 'stall-signals' eval/abtest/run-matrix.sh && /usr/bin/grep -qF 'elif asks > 0 or denials > 0 or escalated > 0:' eval/abtest/lib/stream.py && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `[ "$(pf "$arm" completion_status)" = complete ] || mention=failed`
   indent: 0
   before:
~~~~
      [ "$(pf "$arm" completion_status)" = complete ] || mention=failed
~~~~
   after:
~~~~
      # This case asks only whether the phrase was misread as a usage limit, so a run that answered and then
      # needed a human (stalled-human) still counts as answered; the stall itself is reported and fails the
      # probe below. Any other status (turn-cap, timeout, error) fails here.
      case "$(pf "$arm" completion_status)" in
        complete | stalled-human) ;;
        *) mention=failed ;;
      esac
~~~~
3. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `    [ "$mention" = ok ] || prc=1`
   indent: 0
   insert-after:
~~~~
    # A permission denial or an AskUserQuestion makes a real run stalled-human (spec 4.1, OD-3), so the probe
    # still fails on either, but names the cause here instead of reading as a mention-case failure.
    echo "probe: stall-signals A=$(pf A human_interventions_required) B=$(pf B human_interventions_required)"
    for arm in A B; do
      [ "$(pf "$arm" human_interventions_required)" = 0 ] || prc=1
      denied "$arm" | while IFS= read -r line; do echo "probe-detail: $arm denied $line"; done
    done
~~~~
4. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `    echo "probe: A model=$ma B model=$mb"`
   indent: 0
   insert-after:
~~~~
    nfa="$(printf '%s\n' "$ma" | tr ',' '\n' | awk '!/fable/' | paste -sd, -)"
    nfb="$(printf '%s\n' "$mb" | tr ',' '\n' | awk '!/fable/' | paste -sd, -)"
    echo "probe-detail: A other-models=${nfa:-none} B other-models=${nfb:-none} (reported only; the pass rule is the spec C1.3 rule: fable in each arm)"
~~~~
5. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `# init_cwd ARM: the cwd the CLI reports in its system init record, or nothing.`
   indent: 0
   before:
~~~~
# init_cwd ARM: the cwd the CLI reports in its system init record, or nothing.
~~~~
   after:
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
6. file: `tests/abtest-probe.test.sh`
   anchor: line matching `check "an unknown probe model exits 2" "$?" "2"`
   indent: 0
   insert-after:
~~~~
# --- stall-signal and mixed-model rows (abt-u13c): a correct answer that needed a human proves the mention case but still fails the probe, with the cause named; the real classification stays stalled-human ---
DEN='"permission_denials":[{"tool_name":"Bash","tool_use_id":"t1","tool_input":{"command":"grep -rn x . | grep -v :0 | head"}}]'
resultd() { printf '{"type":"result","subtype":"success","is_error":false,"num_turns":2,"result":"%s",%s,%s}\n' "$1" "$DEN" "$USAGE"; }
ASK='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"AskUserQuestion","input":{}}]}}'
{ printf '%s\n' "$HOOKS"; resultd 'src/pricing.js\ngraph-yes\nrate limit 429'; } > "$T/b-denied.jsonl"
{ printf '%s\n' "$HOOKS"; resultd 'src/pricing.js\ngraph-yes'; } > "$T/b-denied-nomention.jsonl"
{ printf '%s\n' "$HOOKS" "$ASK"; result 'src/pricing.js\ngraph-yes\nrate limit 429'; } > "$T/b-ask.jsonl"
{ printf '%s\n' "$HOOKS"; printf '{"type":"result","subtype":"error_max_turns","is_error":true,"num_turns":100,"result":"src/pricing.js\\ngraph-yes\\nrate limit 429",%s}\n' "$USAGE"; } > "$T/b-turncap.jsonl"
{ resultd 'src/pricing.js\ngraph-no\nrate limit 429'; } > "$T/a-denied.jsonl"
sed 's/"modelUsage":{"fable-x":{"inputTokens":10}}/"modelUsage":{"fable-x":{"inputTokens":10},"haiku-y":{"inputTokens":5}}/' "$T/b-ok.jsonl" > "$T/b-mixed.jsonl"
check "the canned denied Arm B capture carries one permission denial" "$(grep -c 'permission_denials' "$T/b-denied.jsonl")" "1"
PROBE_B="$T/b-denied.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an Arm B that answered correctly but had one permission denial still fails the probe" "$rc" "1"
has "the mention case counts the denied run as answered" "$(cat "$T/o.txt")" "probe: mention-case ok A=complete B=stalled-human"
has "the stall signals are printed for the operator" "$(cat "$T/o.txt")" "probe: stall-signals A=0 B=1"
has "the denied tool and command are printed" "$(cat "$T/o.txt")" "probe-detail: B denied Bash: grep -rn x . | grep -v :0 | head"
check "the stream summary still classifies the denied run stalled-human" "$(grep -c '"completion_status": "stalled-human"' "$ABT_RUNS/probe/B/summary.json")" "1"
PROBE_B="$T/b-denied-nomention.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "a denied Arm B that never wrote the phrase fails the probe" "$rc" "1"
has "the missing phrase is named for the denied run" "$(cat "$T/o.txt")" "probe: mention-case missing A=complete B=stalled-human"
PROBE_B="$T/b-ask.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an Arm B that tried AskUserQuestion but answered still fails the probe" "$rc" "1"
has "the ask attempt is a stall signal" "$(cat "$T/o.txt")" "probe: stall-signals A=0 B=1"
PROBE_B="$T/b-turncap.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an Arm B that hit the turn cap fails the probe even with the phrase" "$rc" "1"
has "the turn cap is named" "$(cat "$T/o.txt")" "probe: mention-case failed A=complete B=turn-cap"
PROBE_A="$T/a-denied.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an Arm A with one permission denial and a correct answer still fails the probe" "$rc" "1"
has "the mention case is symmetric for Arm A" "$(cat "$T/o.txt")" "probe: mention-case ok A=stalled-human B=complete"
has "the Arm A stall signal is printed" "$(cat "$T/o.txt")" "probe: stall-signals A=1 B=0"
has "the Arm A denial is named" "$(cat "$T/o.txt")" "probe-detail: A denied Bash: grep -rn x ."
bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
has "a clean probe prints zero stall signals" "$(cat "$T/o.txt")" "probe: stall-signals A=0 B=0"
check "a clean probe names no denial" "$(grep -c ' denied ' "$T/o.txt")|$rc" "0|0"
check "the canned mixed-model Arm B capture names a second model" "$(grep -c 'haiku-y' "$T/b-mixed.jsonl")" "1"
PROBE_B="$T/b-mixed.jsonl" bash "$RUN" --probe-model uniform > "$T/o.txt"; rc=$?
check "an Arm B that ran fable plus another model still passes the model probe" "$rc" "0"
has "the model line lists every model" "$(cat "$T/o.txt")" "probe: A model=fable-x B model=fable-x,haiku-y"
has "the other models of Arm B are reported" "$(cat "$T/o.txt")" "probe-detail: A other-models=none B other-models=haiku-y"
bash "$RUN" --probe-model uniform > "$T/o.txt"
has "a fable-only probe reports no other models" "$(cat "$T/o.txt")" "probe-detail: A other-models=none B other-models=none"
~~~~
7. command: `bash -n eval/abtest/run-matrix.sh && bash tests/abtest-probe.test.sh | tail -n 1`
   expect: 0
   stdout: `All abtest-probe checks passed.`
8. command: `git add eval/abtest/run-matrix.sh tests/abtest-probe.test.sh && git commit -m "fix(abt-u13c): the probe names a permission denial or an ask as a stall signal instead of a mention-case failure, and reports non-fable models (#620)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/lib/stream.py` (the stalled-human rule: any AskUserQuestion, permission denial or escalation marker means the run needed a human; spec section 4.1 and OD-13 bind it; this unit must not weaken it)
- `eval/abtest/arms/` (the shared `--allowedTools` and deny flags stay as they are; widening them is operator question 1 below, not this unit)
- `tests/abtest-stream.test.sh` and `tests/fixtures/abtest/` (the stream rules and the fake claude are unchanged; the new rows build their captures inside the test)
- `eval/abtest/README.md`, `docs/harness-glossary.md`, `CHANGELOG.md` (a scribe owns the close-out text; this unit adds none)
- `docs/plans/` (never edit a plan or contract by hand), `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)

## Acceptance criteria
1. run: `set -o pipefail; bash tests/abtest-probe.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-probe checks passed.`
   mutation: skip edit 2; three new rows FAIL (the denied run reads as mention-case failed) and the suite exits non-zero.
   proof: scratch git clone of the finished change with only edit 2 reverted: 90 ok, 3 FAIL.
2. run: `bash tests/abtest-probe.test.sh | /usr/bin/grep -c '^ok'`
   exit: 0
   stdout: `93`
   mutation: skip edit 6; 70 rows remain.
   proof: scratch git clone at HEAD (the unmodified suite) printed 70.
3. run: `bash tests/abtest-probe.test.sh | /usr/bin/grep -c '^FAIL'`
   exit: 1
   stdout: `0`
   mutation: skip edit 3; the stall-signal and denied-line rows FAIL and the count is 9.
   proof: scratch git clone of the finished change with only edit 3 reverted: 84 ok, 9 FAIL.
4. run: `/usr/bin/grep -cF 'complete | stalled-human) ;;' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; stdout `0`.
5. run: `/usr/bin/grep -cF 'probe: stall-signals A=' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; stdout `0`.
6. run: `/usr/bin/grep -cF 'A other-models=${nfa:-none} B other-models=${nfb:-none}' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; stdout `0`.
7. run: `/usr/bin/grep -cF 'denied() {' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; stdout `0` (and the suite has 2 FAIL rows).
8. run: `bash tests/abtest-probe.test.sh | /usr/bin/grep -c '^ok   the stream summary still classifies the denied run stalled-human$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; stdout `0`.
9. run: `/usr/bin/grep -cF 'elif asks > 0 or denials > 0 or escalated > 0:' eval/abtest/lib/stream.py`
   exit: 0
   stdout: `1`
   mutation: delete `denials > 0 or ` from that line of eval/abtest/lib/stream.py; stdout `0`.
10. run: `set -o pipefail; bash tests/abtest-stream.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-stream checks passed.`
   mutation: delete `denials > 0 or ` from eval/abtest/lib/stream.py; the denied-capture rows FAIL.
11. run: `set -o pipefail; bash tests/abtest-runner.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-runner checks passed.`
   mutation: add a stray `fi` line to eval/abtest/run-matrix.sh; the runner suite exits non-zero.
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/run-matrix.sh tests/abtest-probe.test.sh`
   mutation: skip edit 8 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; no unit commit exists and the exit is 3.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/run-matrix.sh tests/abtest-probe.test.sh | grep -vcE "^[a-z]+\(abt-u13c\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: a later untagged commit is counted by grep -v, so stdout is 1; with no later commit the count prints 0 (exit 1).
15. run: `git status --porcelain -- eval/abtest/run-matrix.sh tests/abtest-probe.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 8; both files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-probe.test.sh (criteria 2, 3, 5 to 8 are red-then-green: the 23 new rows and the new lines do not exist at HEAD)
blast-radius: eval/abtest/run-matrix.sh:545 eval/abtest/run-matrix.sh:548 eval/abtest/run-matrix.sh:553 eval/abtest/run-matrix.sh:461 eval/abtest/lib/stream.py:152 tests/abtest-probe.test.sh:62 docs/plans/antislop-vs-fable-evals/contracts/abt-u19.md:62 (grep-derived; the `--probe-isolation` block is called nowhere else)
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 of the contract file, keeps its own leading spaces, and states indent: 0; strip nothing; empty payload lines stay empty.
evidence: the first real probe (`bash eval/abtest/run-matrix.sh --probe-isolation --probe-model uniform`) exited 1 with `probe: mention-case failed A=complete B=stalled-human`. Arm B answered `src/pricing.js / graph-yes / rate limit 429` correctly (num_turns 2, subagent_spawns 1), with permission_denials 1 and ask_user_attempts 0.
root-cause-1: the denial is a real unhandled permission prompt, not a hit on a deny flag. The explorer subagent ran the compound command `grep -rn --exclude-dir=.git -c '\bround2\b' . | grep -v ':0$' | head -50; echo "---"; ls -la ...`; the stream record is `permission_denied` with reason_type subcommandResults and the message "This Bash command contains multiple operations. The following part requires approval: grep -v ':0$'". The shared flags allow only `Bash(npm test)`, `Bash(npm run *)` and `Bash(git *)` plus acceptEdits' read-only auto-approval, and no path of the harness root was named.
root-cause-2: stalled-human comes from eval/abtest/lib/stream.py line 152 (`asks > 0 or denials > 0 or escalated > 0`), as the spec section 4.1 and OD-3 and OD-13 require. A denial is a genuine human-stop in a headless run, so the classification and the real-run rows stay as they are. The probe's mention case answers a different question (was the phrase misread as a usage limit), so it now counts complete and stalled-human as answered, names the stall in its own line, and still exits 1: a stall is never passed over.
root-cause-3: the model rule is the spec C1.3 rule (each arm's modelUsage has a key containing fable). The observed B keys were claude-fable-5-1 and claude-haiku-5-5 (the explorer persona runs haiku although CLAUDE_CODE_SUBAGENT_MODEL is set to the fable alias), and A listed claude-fable-5-1 and claude-opus-5-5 with no subagent. The rule passes; the unit adds a reported-only line and does not make extra models fail the probe.
operator-question-1: should the shared `--allowedTools` set (same for both arms, spec line 322) be widened with read-only commands (grep, ls, find, cat, head, wc, sort) so that a subagent's compound read-only command is not denied? Until you decide, the probe and the pilot may report stalled-human for a correct run, which under OD-13 makes the eval not-superior. This unit does not touch the flags. Not decided here: it changes the measured condition of both arms.
operator-question-2: under OD-6 all personas run on Fable, yet the explorer ran haiku in the probe, so the uniform headline policy may not hold in Arm B. Should `--probe-model uniform` fail when Arm B lists a non-fable model? Arm A listed an opus key with no subagent, so a strict rule needs an allowance for internal calls. This unit prints the other models (`probe-detail: ... other-models=`) and keeps the C1.3 pass rule.
u19-note: abt-u19 criterion 6 greps `probe: mention-case ok A=complete B=complete`; it is unchanged and still holds for a clean probe, and a stalled arm prints `B=stalled-human`, so the pilot gate still fails on it.
not-done: the canary probe (abt-u13b) also needs both arms to complete, and its prompt asks for a `find /` that may be denied the same way; it is left alone until the first real canary run shows it.
not-stamped: no agents/*.md or templates/ file is touched, so there is no version bump and no CHANGELOG entry.
commit-message: fix(abt-u13c): the probe names a permission denial or an ask as a stall signal instead of a mention-case failure, and reports non-fable models (#620)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u13c (#620)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
