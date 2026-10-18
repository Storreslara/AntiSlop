#!/usr/bin/env bash
# Tests the --probe-isolation and --probe-model modes of run-matrix.sh with a fake claude whose
# canned stream depends on the arm. Every row compares an explicit expected value, so a crash,
# an empty output or a missing file reads as a failure. No network, no subscription usage.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="$REPO_ROOT/eval/abtest/run-matrix.sh"
FX="$REPO_ROOT/tests/fixtures/abtest"
T="$(mktemp -d)" && [ -d "${T:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }
# has NAME TEXT NEEDLE: NEEDLE must be inside TEXT; an empty TEXT is a failure.
has() { if [ -n "$2" ] && [[ "$2" == *"$3"* ]]; then ok "$1"; else bad "$1 (missing '$3' in '$2')"; fi; }

export HOME="$T/home"
mkdir -p "$HOME/.claude"
printf '{}\n' > "$HOME/.claude/.credentials.json"
export FAKE_CLAUDE_LOG="$T/flog" ABT_RESULTS="$T/results.jsonl" ABT_RUNS="$T/runs" ABT_WORK="$T/work"

# A wrapper that hands Arm B (the one given --plugin-dir) its own canned stream.
cat > "$T/claude" << EOS
#!/usr/bin/env bash
case " \$* " in
  *" --plugin-dir "*) export FAKE_CLAUDE_STREAM="\$PROBE_B" ;;
  *) export FAKE_CLAUDE_STREAM="\$PROBE_A" ;;
esac
exec "$FX/fake-claude.sh" "\$@"
EOS
chmod +x "$T/claude"
export ABTEST_CLAUDE="$T/claude"

# Canned captures for the probe. Arm A: no hooks, answers graph-no and the phrase. Arm B: hooks, a subagent, the phrase.
USAGE='"usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":400},"modelUsage":{"fable-x":{"inputTokens":10}}'
result() { printf '{"type":"result","subtype":"success","is_error":false,"num_turns":2,"result":"%s",%s}\n' "$1" "$USAGE"; }
HOOKS='{"type":"system","subtype":"hook_started","hook_event":"SessionStart","hook_name":"SessionStart:startup"}
{"type":"system","subtype":"hook_response","hook_event":"SessionStart","hook_name":"SessionStart:startup"}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Agent","input":{}}]}}'
{ result 'src/pricing.js\ngraph-no\nrate limit 429'; } > "$T/a-ok.jsonl"
{ printf '%s\n' "$HOOKS"; result 'src/pricing.js\ngraph-yes\nrate limit 429'; } > "$T/b-ok.jsonl"
{ result 'src/pricing.js\ngraph-yes\nrate limit 429'; } > "$T/a-leak.jsonl"
{ result 'src/pricing.js\nrate limit 429'; } > "$T/a-noanswer.jsonl"
{ result 'src/pricing.js\ngraph-no'; } > "$T/a-nomention.jsonl"
{ printf '%s\n' '{"type":"rate_limit_event","rate_limit_info":{"status":"rejected"}}'; result 'src/pricing.js\ngraph-no\nrate limit 429'; } > "$T/a-fp.jsonl"
{ printf '%s\n' '{"type":"system","subtype":"init","cwd":"/home/someone/repo"}'; result 'src/pricing.js\ngraph-no\nrate limit 429'; } > "$T/a-cwd.jsonl"
sed 's/fable-x/sonnet-y/g' "$T/b-ok.jsonl" > "$T/b-sonnet.jsonl"
{ printf '%s\n' '{"type":"system","subtype":"init","agent_type":"spec-master"}'; cat "$T/a-ok.jsonl"; } > "$T/a-persona.jsonl"
grep -v 'hook_' "$T/b-ok.jsonl" > "$T/b-nohooks.jsonl"
grep -v '"Agent"' "$T/b-ok.jsonl" > "$T/b-nospawn.jsonl"
check "the canned Arm A capture has no hook records" "$(grep -c hook "$T/a-ok.jsonl")" "0"
check "the canned Arm B capture has two hook records and a subagent" "$(grep -c 'hook_\|"Agent"' "$T/b-ok.jsonl")" "3"

export PROBE_A="$T/a-ok.jsonl" PROBE_B="$T/b-ok.jsonl"
out="$(bash "$RUN" --probe-isolation)"; rc=$?
check "a clean isolation probe exits 0" "$rc" "0"
has "the isolation line has the spec shape" "$out" "probe: A hook_events=0 persona_refs=0 B hook_events=2 subagent_spawns=1"
check "the isolation line matches the spec regex" "$(printf '%s\n' "$out" | grep -cE '^probe: A hook_events=0 persona_refs=0 B hook_events=[1-9][0-9]* subagent_spawns=[1-9][0-9]*$')" "1"
has "Arm A does not see this checkout's CLAUDE.md" "$out" "probe: A root_claude_md=not-loaded"
has "the mention case is classified complete in both arms" "$out" "probe: mention-case ok A=complete B=complete"
has "the probe reports the max-turns flag as accepted" "$out" "max-turns flag accepted=yes"
has "the probe lists record types for the operator" "$out" "probe-detail: B record types:"
check "the hook name census is written" "$(test -s "$ABT_RUNS/probe/B/hook-names.txt" && echo yes)" "yes"
check "both probe runs were built under ABT_WORK, outside the repo" "$(grep -l "^PWD=$T/work/probe_" "$T"/flog/env.* | wc -l | tr -d ' ')" "2"
check "the probe prompt asks the CLAUDE.md question" "$(grep -c 'graph-yes' "$ABT_RUNS/probe/A/prompt.md")" "1"
check "the probe prompt asks for the mention phrase" "$(grep -c 'rate limit 429' "$ABT_RUNS/probe/A/prompt.md")" "1"

out="$(bash "$RUN" --probe-model uniform)"; rc=$?
check "a clean model probe exits 0" "$rc" "0"
check "the model line matches the spec regex" "$(printf '%s\n' "$out" | grep -cE '^probe: A model=.*fable.* B model=.*fable.*$')" "1"

rm -rf "$T/flog"
out="$(bash "$RUN" --probe-isolation --probe-model uniform)"; rc=$?
check "both probes in one call exit 0" "$rc" "0"
has "both lines print" "$out" "probe: A model="
check "both probes share one pair of runs" "$(ls "$T/flog" | grep -c '^argv\.')" "2"

PROBE_A="$T/a-leak.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an Arm A that reports this checkout's CLAUDE.md fails the probe" "$rc" "1"
has "the leak is named" "$(cat "$T/o.txt")" "probe: A root_claude_md=loaded"
PROBE_A="$T/a-noanswer.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an Arm A that does not answer the CLAUDE.md question fails the probe" "$rc" "1"
has "the missing answer is named" "$(cat "$T/o.txt")" "probe: A root_claude_md=no-answer"
PROBE_A="$T/a-cwd.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an Arm A whose reported cwd is outside the work root fails the probe" "$rc" "1"
has "the cwd rule is named" "$(cat "$T/o.txt")" "probe: A cwd is outside the work root"
PROBE_A="$T/a-nomention.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an arm that never wrote the mention phrase fails the probe" "$rc" "1"
has "the unexercised mention case is named" "$(cat "$T/o.txt")" "probe: mention-case missing"
PROBE_A="$T/a-fp.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "a usage-limit verdict on a run that answered the phrase fails the probe with exit 1" "$rc" "1"
has "the false positive is named" "$(cat "$T/o.txt")" "probe: usage-limit false positive on arm A"

PROBE_B="$T/a-ok.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an arm B without hook events fails the probe" "$rc" "1"
has "the failing line shows zero hook events for B" "$(cat "$T/o.txt")" "B hook_events=0 subagent_spawns=0"
PROBE_A="$T/a-persona.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an arm A that names a persona agent type fails the probe" "$rc" "1"
has "the line shows the persona reference" "$(cat "$T/o.txt")" "persona_refs=1"
PROBE_B="$T/b-nohooks.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an arm B with a subagent but no hook events fails the probe" "$rc" "1"
has "the line shows no hook events but one spawn" "$(cat "$T/o.txt")" "B hook_events=0 subagent_spawns=1"
PROBE_B="$T/b-nospawn.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an arm B with hook events but no subagent fails the probe" "$rc" "1"
has "the line shows hook events but no spawn" "$(cat "$T/o.txt")" "B hook_events=2 subagent_spawns=0"
PROBE_A="$T/b-ok.jsonl" bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "an arm A with hook events fails the probe" "$rc" "1"
has "the failing line shows hook events for A" "$(cat "$T/o.txt")" "probe: A hook_events=2"
PROBE_B="$T/b-sonnet.jsonl" bash "$RUN" --probe-model uniform > "$T/o.txt"; rc=$?
check "a model without fable fails the probe" "$rc" "1"
has "the model line shows what ran" "$(cat "$T/o.txt")" "B model=sonnet-y"

PROBE_B="$FX/streams/limit-text.jsonl" FAKE_CLAUDE_EXIT=1 bash "$RUN" --probe-isolation > "$T/o.txt"; rc=$?
check "a real usage limit during the probe exits 75" "$rc" "75"
FAKE_CLAUDE_STDERR="error: unknown option '--max-turns'" bash "$RUN" --probe-isolation > "$T/o.txt"
has "a rejected max-turns flag is reported" "$(cat "$T/o.txt")" "max-turns flag accepted=no"

bash "$RUN" --probe-model other > /dev/null 2>&1
check "an unknown probe model exits 2" "$?" "2"
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

echo "abtest-probe: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-probe checks passed."
exit "$fail"
