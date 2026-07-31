#!/usr/bin/env bash
# Behavioral regression suite for hooks/scripts/reviewed-path-gate.sh: the
# write-intent allowlist on the Bash path (Step 1) and the identity check on the
# Write/Edit path (Step 2). Canned hook-input JSON piped over stdin, fixtures
# seeded under mktemp -d - no claude CLI, no network, no live dispatch.
#
# Per spec R4 every assertion that spells the marker directory lives in THIS
# file, so the suite is invoked by a command whose own text is clean and cannot
# trip the very gate under test.
#
# Fixture hygiene: testAndLintCommand is "true", NEVER this repo's
# `bash tests/validate.sh` - this suite runs FROM validate.sh and would recurse.
#
# Every command below is built from $marker, so the gate's substring early-exit
# is never what produces an `allowed` verdict: the path is present by
# construction and the verdict comes from the matcher. Case 19 is the one
# deliberate exception and asserts the opposite.
set -euo pipefail
cd "$(dirname "$0")/.."
unset CLAUDE_PLUGIN_ROOT || true
fail=0

marker=".claude/reviewed"
gate=hooks/scripts/reviewed-path-gate.sh

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT
errf="$tmproot/stderr"

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

cfg_reviewer='{"gatedAgents":["lead-programmer"],"personaSelection":["reviewer"],"testAndLintCommand":"true"}'
cfg_none='{"gatedAgents":["lead-programmer"],"personaSelection":["explorer"],"testAndLintCommand":"true"}'

mk() {
  local d="$tmproot/$1"
  mkdir -p "$d/.claude/reviewed"
  printf '%s\n' "$2" > "$d/.claude/persona-config.json"
  printf '%s' "$d"
}
proj="$(mk with-reviewer "$cfg_reviewer")"
proj_none="$(mk no-reviewer "$cfg_none")"

rc=0
run() {
  rc=0
  : > "$errf"
  printf '%s' "$1" | CLAUDE_PROJECT_DIR="$2" bash "$gate" >/dev/null 2>"$errf" || rc=$?
}

# Exact exit codes on purpose: a script that crashes under `set -e` exits 1, and
# a blocked verdict must also carry a reason on stderr, so neither can be
# mistaken for a deliberate block.
check() {
  if [ "$2" = allowed ]; then
    [ "$rc" = 0 ] && pass "$1 -> allowed" || bad "$1 -> rc=$rc, expected 0 (allowed)"
  elif [ "$rc" = 2 ] && [ -s "$errf" ]; then
    pass "$1 -> blocked"
  else
    bad "$1 -> rc=$rc with $(wc -c < "$errf") bytes of stderr, expected rc=2 and a reason"
  fi
}

# $1 label, $2 verdict, $3 agent_type, $4 command, $5 project dir (default $proj)
bash_case() {
  run "$(jq -n --arg a "$3" --arg c "$4" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')" \
      "${5:-$proj}"
  check "$1" "$2"
}

# $1 label, $2 verdict, $3 agent_type, $4 file_path, $5 project dir
write_case() {
  run "$(jq -n --arg a "$3" --arg p "$4" '{tool_name:"Write",agent_type:$a,tool_input:{file_path:$p}}')" \
      "${5:-$proj}"
  check "$1" "$2"
}

echo "-- now-allowed: text-only mentions and read-only inspection (#155 false positives) --"
bash_case "case 1  gh issue close naming the path, as scribe" allowed scribe \
  "gh issue close 9 --comment \"Verdict recorded at $marker/9.pass\""
bash_case "case 2  gh issue create naming the path, as orchestrator (#154)" allowed orchestrator \
  "gh issue create --title Followup --body \"See $marker/9.pass for the verdict\""
bash_case "case 3  ls of the marker dir, as task-master" allowed task-master \
  "ls -la $marker/"
bash_case "case 4  cat of a marker file, as spec-master" allowed spec-master \
  "cat $marker/9.fail"
bash_case "case 5  git commit message naming the path, as lead-programmer" allowed lead-programmer \
  "git commit -m \"fix: record the verdict under $marker\""

echo
echo "-- still blocked: write intent --"
bash_case "case 6  printf redirected into the marker dir" blocked lead-programmer \
  "printf x > $marker/9.pass"
for c in "rm $marker/9.pass" \
         "mv $marker/9.pass $marker/9.fail" \
         "cp /dev/null $marker/9.pass" \
         "tee $marker/9.pass" \
         "touch $marker/9.pass" \
         "mkdir -p $marker/sub" \
         "sed -i s/a/b/ $marker/9.pass"; do
  bash_case "case 7  ${c%% *} form" blocked lead-programmer "$c"
done
bash_case "case 8  compound: allowlisted segment then rm" blocked lead-programmer \
  "ls $marker/ && rm $marker/9.pass"
bash_case "case 9  compound: allowlisted segment then redirection" blocked lead-programmer \
  "ls $marker/; printf x > $marker/9.pass"
bash_case "case 10 redirection despite an allowlisted program" blocked lead-programmer \
  "gh issue view 1 --json body > $marker/9.pass"
bash_case "case 11a eval" blocked lead-programmer "eval ls $marker"
bash_case "case 11b exec" blocked lead-programmer "exec ls $marker"
bash_case "case 11c source" blocked lead-programmer "source $marker/9.pass"
bash_case "case 11d backtick substitution" blocked lead-programmer \
  "echo \`cat $marker/9.pass\`"
bash_case "case 11e \$( ) substitution" blocked lead-programmer \
  "echo \$(cat $marker/9.pass)"
bash_case "case 12 non-allowlisted git subcommand" blocked lead-programmer \
  "git rm $marker/9.pass"

echo
echo "-- still blocked: the five fail-open bypasses closed in 273c7b1 --"
bash_case "case 12a bare & as a segment separator" blocked lead-programmer \
  "ls $marker & rm $marker/9.pass"
bash_case "case 12b process substitution" blocked lead-programmer \
  "cat <(rm $marker/9.pass)"
bash_case "case 12c git --output= on an allowlisted subcommand" blocked lead-programmer \
  "git diff --output=$marker/9.pass"
bash_case "case 12d gh subcommand outside the allowlist" blocked lead-programmer \
  "gh run download -D $marker"
bash_case "case 12e rg --pre runs a command of its own" blocked lead-programmer \
  "rg --pre /bin/sh pattern $marker"
bash_case "case 12f rg --pretty is not --pre (no over-block)" allowed lead-programmer \
  "rg --pretty pattern $marker"
bash_case "case 12g leading VAR=value assignment disqualifies the segment" blocked lead-programmer \
  "FOO=bar ls $marker"

echo
echo "-- identity rules preserved --"
for id in reviewer antislop:reviewer; do
  bash_case "case 13 $id performing case 6's write (GRANT intact)" allowed "$id" \
    "printf x > $marker/9.pass"
done
# Case 14 (amended per A2): the command kind is load-bearing. Both halves use
# case 6's WRITE-INTENT command, so what is being asserted is the no-reviewer
# fallback itself, not the benign carve-out.
bash_case "case 14 empty agent_type + write intent, no reviewer selected (fallback intact)" \
  allowed "" "printf x > $marker/9.pass" "$proj_none"
bash_case "case 14 empty agent_type + write intent, reviewer selected" \
  blocked "" "printf x > $marker/9.pass" "$proj"
# Case 14b (added per A2, spec R9): read-only access is allowed OUTRIGHT, for
# every identity, and does not depend on the no-reviewer fallback. This is the
# placement assertion - with the benign check placed after the empty-agent_type
# block instead of before it, this exact case is the only one that flips.
bash_case "case 14b empty agent_type + read-only, reviewer selected (A2 placement)" \
  allowed "" "ls -la $marker/" "$proj"

echo
echo "-- Write/Edit tool path (Step 2) --"
write_case "case 15 Write into the marker dir as lead-programmer" blocked lead-programmer \
  "$marker/9.pass"
write_case "case 16 Write into the marker dir as reviewer (GRANT intact)" allowed reviewer \
  "$marker/9.pass"
write_case "case 17 Write to an unrelated path as lead-programmer (no over-block)" allowed \
  lead-programmer "docs/notes.md"
write_case "case 18 absolute-path form of case 15 (normalization)" blocked lead-programmer \
  "$proj/$marker/9.pass"
write_case "case 18b dot-segment form of case 15 (normalization)" blocked lead-programmer \
  ".claude/agents/../reviewed/9.pass"
run '{"tool_name":"NotebookEdit","agent_type":"lead-programmer","tool_input":{"notebook_path":".claude/reviewed/9.ipynb"}}' "$proj"
check "case 18c payload with no file_path key at all (notebook editing unaffected)" allowed
run '{"tool_name":"Write","agent_type":"lead-programmer","tool_input":{"file_path":""}}' "$proj"
check "case 18d Write with an unreadable target fails closed" blocked

echo
echo "-- pinned known limitation (control) --"
# Case 19: the accepted residual bypass from the spec's Clarifications log. The
# path is assembled by shell expansion, so the raw command text never spells it
# and the gate's substring early-exit lets it through. Closing this requires
# resolving shell expansion, which no hook can do without executing the command.
# Asserted explicitly so a future reader sees a KNOWN state, not a gap.
obfuscated='d=.claude/re; printf x > ${d}viewed/9.pass'
case "$obfuscated" in
  *"$marker"*) bad "case 19 fixture no longer obfuscates the path - the control is dead" ;;
  *) bash_case "case 19 variable-split obfuscation (accepted residual bypass)" allowed \
       lead-programmer "$obfuscated" ;;
esac

echo
echo "-- quote-aware operator detection (R8's residue, closed by Step 6) --"
# Cases 20-22 were OVER-blocks until Step 6 landed: the operator scan and the
# segment split inspected raw text, so a '>' or ';' inside a quoted string was
# read as an operator and '2>/dev/null' as a write. Step 6 runs both conditions
# on a quote-aware skeleton and exempts exactly two redirection forms, so all
# three are now allowed. They stay pinned as the fixtures that prove it.
bash_case "case 20 gh comment containing '->' as scribe (Step 6 landed)" \
  allowed scribe "gh issue close 9 --comment \"$marker/9.pass -> merged\""
bash_case "case 21 fd redirection on a read-only command as task-master (Step 6 landed)" \
  allowed task-master "ls $marker 2>/dev/null"
bash_case "case 22 gh comment containing ';' as scribe (Step 6 landed)" \
  allowed scribe "gh issue close 9 --comment \"$marker/9.pass; then merge\""
for c in "cat $marker/9.fail 2>&1" \
         "echo $marker >&2" \
         "gh issue close 9 --comment \"$marker/9.pass\" --body \"a; b -> c\""; do
  bash_case "case 23 quote/fd form still read-only: ${c%% *} form" allowed task-master "$c"
done
# Case 23b pins a deliberate consequence of moving the eval/exec/source scan onto
# the skeleton: those words inside quotes are argument text, so they no longer
# disqualify. Cases 11a-11c pin the unquoted forms, which still do.
bash_case "case 23b quoted eval/exec/source are argument text, not code" \
  allowed scribe "gh issue close 9 --comment \"$marker/9.pass: do not eval, exec or source it\""

echo
echo "-- Step 6's fail-closed edges: unparseable, or only shaped like an exemption --"
# The skeletonizer refuses to guess: an unbalanced quote, ANY backslash escape,
# or a heredoc operator makes the command unresolvable, and unresolvable is never
# benign. The rest are near-misses of the two exempt redirection forms - 24.4
# isolates the spacing rule and 24.5 the target rule (conflated before), and 24.6
# pins the trailing anchor, without which '/dev/null/../..' would traverse back
# into the marker directory. Plus the reason the substitution scan deliberately
# keeps reading RAW text - double quotes do not inhibit '$(', so a skeleton would
# hide a live substitution.
n=0
for c in "cat \"$marker/9.fail" \
         "echo \"a\\\"b\\\"c\" $marker" \
         "ls $marker >&$marker/9.pass" \
         "ls $marker > /dev/null" \
         "ls $marker >/dev/null.txt" \
         "ls $marker >/dev/null/../../$marker/9.pass" \
         "echo \"\$(rm $marker/9.pass)\"" \
         "ls \"$marker/a; ls b\"; rm $marker/9.pass" \
         "echo a\\ # x > $marker/9.pass" \
         "ls $marker <<EOF"; do
  n=$((n + 1))
  bash_case "case 24.$n ${c%% *} form" blocked lead-programmer "$c"
done

echo
echo "-- '#' comments are inert, and only where bash says one starts --"
# A '#' comment runs to end of line and the quote characters inside it do NOT
# quote anything. Reading them as quoting made the skeleton mask the NEWLINE
# between two lines, so the segment split never saw the separator and only the
# first, allowlisted line was ever checked - the fail-open found reviewing #182.
bash_case "case 25.1 quote in a comment must not swallow the newline before rm" \
  blocked lead-programmer "ls $marker  # don't peek
rm $marker/9.pass  # it's fine"
bash_case "case 25.2 same, hiding a redirection instead of a program" \
  blocked lead-programmer "ls $marker  # don't peek
printf HACKED > $marker/9.pass  # it's fine"
# The converse over-correction is a fail-open of its own: masking from a '#' that
# bash does NOT read as a comment hides every operator after it on that line. So
# 25.3 and 25.4 are the probes that pin WHERE a comment may start - mid-word and
# inside quotes are the two places it may not, and bash really does redirect in
# both. Asserting the read-only forms (25.5, 25.6) allowed is not enough on its
# own: masking to end of line erases a quote PAIR, so nothing goes unbalanced and
# the verdict does not move.
bash_case "case 25.3 mid-word '#' must not hide a same-line redirection" \
  blocked lead-programmer "cat $marker/issue#9.fail > $marker/9.pass"
bash_case "case 25.4 '#' inside quotes must not hide a same-line redirection" \
  blocked lead-programmer "echo \"a # b\" > $marker/9.pass"
bash_case "case 25.5 mid-word '#' in a read-only command is no over-block" \
  allowed lead-programmer "cat $marker/issue#9.fail \"$marker/9.pass\""
bash_case "case 25.6 '#' inside a quoted string is no over-block" \
  allowed scribe "gh issue close 9 --comment \"$marker/9.pass # not a comment\""
bash_case "case 25.7 a real comment's '#', '>' and stray quote are all inert" \
  allowed task-master "ls $marker  # see issue #9 -> merged, don't peek"
# Case 25.8: the same root cause through a heredoc instead of a comment - the
# quote characters in a heredoc BODY are not quoting either, so they used to pair
# up across the newlines and hide the rm in the middle. Heredocs are not modelled
# at all; the '<<' operator itself is what disqualifies.
bash_case "case 25.8 quotes in a heredoc body must not swallow the newlines" \
  blocked lead-programmer "ls $marker <<ls
ls \"
ls
rm $marker/9.pass
cat <<ls
ls \"
ls"

echo
echo "-- where a comment may start: bash's metacharacters, not POSIX [[:space:]] --"
# The predecessor set for a comment's '#' is bash's metacharacter set, which is
# NOT the POSIX space class: they differ by exactly VT/FF/CR, which bash treats
# as ordinary word characters. Reading those three as word boundaries masked the
# rest of the line - including the ';' before a second command - so only the
# first, allowlisted command was ever checked (the fail-open found reviewing
# #182's second attempt; see docs/plans/2026-07-31-debug-182-step6-word-boundary.md).
# 25.9-25.11 pin the three excluded bytes blocked; 25.12-25.13 pin that the
# narrowing did not overshoot onto tab and space, which ARE boundaries. A naive
# textual substitution of the class rejects those two, and none of the 67
# assertions above notices.
n=0
for b in '\013' '\014' '\015'; do
  n=$((n + 1))
  byte="$(printf "$b")"
  bash_case "case 25.$((8 + n)) '#' after $b (VT/FF/CR) is not a word start" \
    blocked lead-programmer "ls $marker$byte#x; rm $marker/9.pass"
done
for b in '\011' '\040'; do
  n=$((n + 1))
  byte="$(printf "$b")"
  bash_case "case 25.$((8 + n)) '#' after $b (tab/space) IS a word start (no over-block)" \
    allowed lead-programmer "ls $marker$byte#x; rm $marker/9.pass"
done

echo
exit "$fail"
