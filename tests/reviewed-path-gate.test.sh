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
# Overridable so the case 26 mutation control can point the whole suite at a
# mutated scratch copy without editing the gate in place. Defaults to the real one.
gate="${GATE_UNDER_TEST:-hooks/scripts/reviewed-path-gate.sh}"

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
bash_case "case 12d gh subcommand outside the allowlist" blocked lead-programmer \
  "gh run download -D $marker"
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
# Case 24.6b pins the `fd` branch's trailing anchor, mirroring what 24.6 does for
# the `devnull` branch: without an anchor, `>&1` would be exempted out of a
# command that goes on to name a path, and the `>` would vanish with it. This is
# a REGRESSION PIN, not a bug fix - it was already blocked before 6R-1 touched
# the anchors (verified exit 2 at 5836d99); the gap was that nothing pinned it
# while line 121 was being edited. Distinct from 24.3, which is the no-digits
# `>&<path>` form and fails the `&[0-9]+` test instead of the anchor.
bash_case "case 24.6b fd-branch trailing anchor (>&N followed by a path)" \
  blocked lead-programmer "ls $marker >&1$marker/9.pass"

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
# bash does NOT read as a comment hides every operator after it on that line.
# 25.3 pins the mid-word case, where bash really does redirect, and it is killed
# by dropping the word-start test.
#
# 25.4 is deliberately weaker, and is labelled here so no later reader overrates
# it: it documents a design invariant, and is NOT a mutation-proven assertion.
# The quote branch consumes "a # b" before the '#' can ever reach the logic,
# because quoted spans and comments are resolved in the SAME left-to-right pass -
# so no natural mutant of this implementation kills it. It is kept as
# documentation of that ordering. A contrived fixture that merely looked stronger
# would be a test that lies, so the fixture and the verdict are left alone.
#
# Asserting the read-only forms (25.5, 25.6) allowed is not enough on its own:
# masking to end of line erases a quote PAIR, so nothing goes unbalanced and
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
echo "-- case 26: differential boundary-byte sweep (T1-T5 x 0x01-0x7F) --"
# Everything above this line is example-based, and example-based criteria let two
# consecutive fail-opens land on command_skeleton(): its contract is universally
# quantified over bash's input space, but the suite only ever quantified over the
# constructs somebody thought of. Both review rounds ran a byte sweep against
# real bash by hand, found the bug, and then threw the sweep away. This is that
# sweep, kept.
#
# Five templates, one per lexing decision point, crossed with every byte 0x01 to
# 0x7F with no exclusions. Per probe: run the gate FIRST; if it blocks, the probe
# passes and we stop, because blocking is always safe. Only if the gate ALLOWS do
# we execute the identical payload with real bash, in a throwaway sandbox seeded
# with a sentinel. The probe fails only when the gate said yes and real bash then
# touched the marker directory. The sweep is one-directional by construction: it
# never asserts that a probe is allowed, because doing so would freeze today's
# over-blocks in as required behaviour and contradict Step 6's own goal.
#
# MUTATION CONTROL (reviewer-run, 6R-2.7). Reintroduce attempt 2's bug in a
# scratch copy and point the suite at it. Copy lib/ alongside it: the gate
# sources lib/agent-identity.sh relative to its OWN path, so a bare copy into an
# empty directory dies at startup and every case "fails" with rc=1 - which looks
# like a kill but proves nothing.
#
#   d="$(mktemp -d)"; cp -r hooks/scripts/lib "$d/"
#   sed "s/''|\[\$' .t.n'\]|/''|[[:space:]]|/" \
#     hooks/scripts/reviewed-path-gate.sh > "$d/mutant.sh"
#   GATE_UNDER_TEST="$d/mutant.sh" bash tests/reviewed-path-gate.test.sh; echo $?
#
# That restores the POSIX space class as the comment word-start predecessor.
# Expected: exit 1 with exactly 6 FAIL lines - cases 25.9, 25.10 and 25.11 (the
# literal VT/FF/CR probes) plus three case 26 T1 lines, at bytes 0x0B, 0x0C and
# 0x0D. The floor required by 6R-2.7 is >= 4. Check the rc on those FAIL lines:
# rc=0 means the gate allowed a payload it should have blocked, which is the
# kill; rc=1 means the mutant crashed and the run is void.
sweep_allowed=0
sweep_probes=0

# Sets $rc for one payload and asserts nothing - the sweep decides what to do
# with the verdict. Deliberately not bash_case, which always asserts.
bash_run() {
  run "$(jq -n --arg a lead-programmer --arg c "$1" \
    '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')" "$proj"
}

# $1 template id, $2 byte in hex, $3 payload. Only ever called for payloads the
# gate ALLOWED, so any effect on the marker directory is a fail-open by
# definition. Runs in its own sandbox, cd'd into, and removed afterwards.
sweep_differential() {
  local box entries
  box="$(mktemp -d "$tmproot/sweep.XXXXXX")"
  mkdir -p "$box/$marker"
  printf 'SENTINEL' > "$box/$marker/9.pass"
  ( cd "$box" && bash -c "$3" ) >/dev/null 2>&1 </dev/null || true
  entries="$( (cd "$box/$marker" && ls -A) 2>/dev/null || true )"
  if [ "$(cat "$box/$marker/9.pass" 2>/dev/null || true)" != SENTINEL ]; then
    bad "case $1 byte $2: gate ALLOWED it, real bash altered or removed the sentinel"
  elif [ "$entries" != "9.pass" ]; then
    bad "case $1 byte $2: gate ALLOWED it, real bash added an entry under the marker dir"
  fi
  rm -rf "$box"
}

for ((b = 1; b <= 127; b++)); do
  byte="$(printf "\\$(printf '%03o' "$b")"; printf .)"
  byte="${byte%.}"
  hex="$(printf '0x%02X' "$b")"
  for t in T1 T2 T5; do
    case "$t" in
      T1) payload="ls $marker$byte#x; rm -f $marker/9.pass" ;;        # comment word-start predecessor
      T2) payload="ls $marker #x${byte}rm -f $marker/9.pass" ;;       # comment terminator
      T5) payload="ls $marker${byte}rm -f $marker/9.pass" ;;          # segment separator set
    esac
    sweep_probes=$((sweep_probes + 1))
    bash_run "$payload"
    [ "$rc" = 0 ] || continue
    sweep_allowed=$((sweep_allowed + 1))
    sweep_differential "26 $t" "$hex" "$payload"
  done
done

echo "     case 26 sweep: $sweep_probes probes, gate ALLOWED $sweep_allowed of them"
# Non-vacuity floor. A future change that simply blocked everything would drive
# the fail-open count to 0 and make the sweep pass for the wrong reason; this is
# the assertion that fails instead. Measured on the fixed gate: 247 of 381.
if [ "$sweep_allowed" -ge 200 ]; then
  pass "case 26 non-vacuity floor ($sweep_allowed gate-allowed probes >= 200)"
else
  bad "case 26 non-vacuity floor: only $sweep_allowed gate-allowed probes (< 200) - the sweep is passing vacuously"
fi

echo
echo "-- ratified residuals: known over-blocks, pinned so they are not re-litigated --"
# Both cases below are over-blocks the gate keeps ON PURPOSE (issue #183,
# docs/plans/2026-07-31-debug-182-step6-word-boundary.md step 6R-4). They are
# pinned so a later pass reads them as decided, not as an oversight to "fix" -
# and so that if someone does decide to narrow them, it is a deliberate change to
# a named assertion rather than a silent drift.
#
# 27.1/27.2: ANY backslash makes the command unresolvable to the skeletonizer, so
# it fails closed - an escaped space defeats the word-start test exactly as an
# escaped quote defeats quote pairing. Narrowing this to "only the interesting
# backslashes" is the same species of clever, narrowly-scoped lexer rule that
# produced both prior fail-opens, so the broad rule stays. Documented workaround:
# quote the path instead of escaping it, which 27.2 pins as allowed.
bash_case "case 27.1 escaped space fails closed (ratified residual)" \
  blocked lead-programmer "cat $marker/a\ b"
bash_case "case 27.2 the documented workaround - quote it instead - is allowed" \
  allowed lead-programmer "cat \"$marker/a b\""
# 27.3: a trailing segment that is entirely a comment is blocked, because after
# the comment is masked the segment's first word is the '#' itself, which is not
# allowlisted. Ratified as blocked (OQ1, resolved 2026-07-31): the alternative is
# new masking logic in a function that has now failed twice, and "model one more
# construct" is precisely the move that produced those failures. Documented
# workaround: put the comment above the command, or omit it.
bash_case "case 27.3 comment-only trailing segment stays blocked (ratified residual, OQ1)" \
  blocked lead-programmer "ls $marker
# note"

echo
echo "-- case 30: git and rg are off the allowlist entirely (#186) --"
# Both were allowlisted with a flag scan guarding the options that make them
# write or run a program. Both were removed outright instead: each consults
# out-of-band configuration - read at run time from disk or the environment and
# named nowhere in the command line - that can point it at a program of the
# caller's choosing, which no scan of the command's own text can see. The eight
# forms below are exactly the shapes that used to be ALLOWED: the seven git
# subcommands the old allowlist named, plus rg.
#
# ANTI-VACUITY / MUTATION CONTROL (reviewer-run, AC1.8). This suite lost its
# git/rg fixtures with the removal, so the risk here is not a subtle predicate -
# it is that nothing is being tested at all. Point the reconciled suite at the
# pre-removal gate (aff5b35 is the commit before the removal landed):
#
#   d="$(mktemp -d)"; cp -r hooks/scripts/lib "$d/"
#   git show aff5b35:hooks/scripts/reviewed-path-gate.sh > "$d/unfixed.sh"
#   GATE_UNDER_TEST="$d/unfixed.sh" bash tests/reviewed-path-gate.test.sh; echo $?
#
# Expected: exit 1 with EXACTLY 8 FAIL lines, all of them case 30 blocked forms,
# every one reading rc=0 - the pre-removal gate really did allow them. Two traps
# either of which turns the control into a void run that only looks like a kill.
# GATE_UNDER_TEST must be an ABSOLUTE path (mktemp -d gives one); a relative one
# makes every case read rc=127. And lib/ must sit beside the copy, or the gate
# dies sourcing lib/agent-identity.sh and every case reads rc=1.
for c in "git log --oneline -- $marker" \
         "git diff --stat HEAD -- $marker" \
         "git show HEAD -- $marker" \
         "git status $marker" \
         "git blame $marker/9.pass" \
         "git tag -l -- $marker" \
         "git commit -m \"note about $marker\"" \
         "rg pat $marker"; do
  bash_case "case 30 off the allowlist: $c" blocked lead-programmer "$c"
done
# The over-block bound: removing two entries must leave read-only inspection and
# gh text-mentions untouched. The last three are RELOCATED from the retired
# flag-boundary block rather than deleted with their neighbours.
for c in "grep -r pat $marker" \
         "ls -la $marker" \
         "cat $marker/9.pass" \
         "head -1 $marker/9.pass" \
         "wc -l $marker/9.pass" \
         "test -f $marker/9.pass" \
         "sha256sum $marker/9.pass" \
         "gh issue close 9 --comment \"see $marker/9.pass\""; do
  bash_case "case 30 allow-control: $c" allowed lead-programmer "$c"
done
echo

echo "-- case 31: block-direction, redirection-exemption trailing anchors (A5, promoted from case 26 T3/T4) --"
# Case 26's differential sweep above is vacuous for these two templates and was
# narrowed to drop them (T3: fd-exemption trailing anchor "ls $marker >&1<byte>...";
# T4: /dev/null-exemption trailing anchor "ls $marker >/dev/null<byte>..."). Three
# independent measurements (docs/plans/2026-08-07-gate-audit-t34-vacuity-and-gh-inventory.md,
# Step 1, Context item 1) establish there is no byte at which the gate believes
# these are inert and real bash actually writes into the marker directory: the
# masked prefix is glued to the tail in both templates, so the filename bash
# would open is never the bare marker path. A5 prescribes this block-direction
# case in place of re-measuring a differential that has no effect to observe -
# not "to be re-measured later", the effect is structurally unobservable for
# this template family.
#
# This does NOT contradict case 26's own "a differential sweep never asserts
# allowed" principle - that principle is scoped to the sweep above, whose
# allowed set is incidental to what real bash does with it. Case 31 is a
# block-direction case instead, and like case 30 it needs an explicit
# allow-control or it could pass by blocking everything.
#
# ANTI-VACUITY / MUTATION CONTROL (reviewer-run, not part of the loops below).
# Same mutant as case 26's own control: widen the comment word-start
# predecessor set back to the POSIX space class, which is the anchor set
# these two templates' trailing bytes key off of.
#
#   d="$(mktemp -d)"; cp -r hooks/scripts/lib "$d/"
#   sed "s/pad meta=\$' \\\\t\\\\n;&|()<>'/pad meta=\$' \\\\t\\\\n\\\\v\\\\f\\\\r;\&|()<>'/" \
#     hooks/scripts/reviewed-path-gate.sh > "$d/mutant.sh"
#   grep -n "meta=" "$d/mutant.sh" | head -1
#   GATE_UNDER_TEST="$d/mutant.sh" bash tests/reviewed-path-gate.test.sh; echo $?
#
# Expected: exit 1 with exactly 6 FAIL lines, all case 31, at bytes 0x0B, 0x0C
# and 0x0D on both templates, every one reading rc=0. rc=1 means the mutant
# crashed sourcing lib/agent-identity.sh (lib/ not copied beside it) and the
# run is void - GATE_UNDER_TEST must be an ABSOLUTE path or every case reads
# rc=127.
allow_bytes_31="09 20 28 29 3C"
is_allow_byte_31() {
  local hb="$1" ab
  for ab in $allow_bytes_31; do
    [ "$hb" = "$ab" ] && return 0
  done
  return 1
}
for ((b = 1; b <= 127; b++)); do
  byte="$(printf "\\$(printf '%03o' "$b")"; printf .)"
  byte="${byte%.}"
  hexb="$(printf '%02X' "$b")"
  hex="0x$hexb"
  is_allow_byte_31 "$hexb" && continue
  for t in T3 T4; do
    case "$t" in
      T3) c="ls $marker >&1$byte$marker/9.pass" ;;
      T4) c="ls $marker >/dev/null$byte$marker/9.pass" ;;
    esac
    bash_case "case 31 $t byte $hex" blocked lead-programmer "$c"
  done
done
for ab in $allow_bytes_31; do
  b=$((16#$ab))
  byte="$(printf "\\$(printf '%03o' "$b")"; printf .)"
  byte="${byte%.}"
  hex="0x$ab"
  for t in T3 T4; do
    case "$t" in
      T3) c="ls $marker >&1$byte$marker/9.pass" ;;
      T4) c="ls $marker >/dev/null$byte$marker/9.pass" ;;
    esac
    bash_case "case 31 $t byte $hex allow-control" allowed lead-programmer "$c"
  done
done
echo

echo "-- case 32: gh api is off the allowlist, issue/pr/search stay (#185 item 2) --"
# gh api was allowlisted whole, with no further check. It is a general-purpose
# authenticated HTTP client whose HTTP method is IMPLICIT - GET normally, POST
# as soon as any -f/-F/--field/--raw-field is present, with no -X required -
# and it also reaches GraphQL mutations via `gh api graphql -f query=...`,
# naming no REST route at all. No scan of the command's own text can bound
# what a call like this writes, which is the same denylist-fails-open ground
# already ratified for `git`/`rg` in case 30 above: the surface is removed
# rather than inspected. `issue`, `pr` and `search` are unaffected - none of
# them takes a flag that writes a caller-named local path (audited in
# docs/plans/2026-08-07-gate-audit-t34-vacuity-and-gh-inventory.md, Step 2).
#
# ANTI-VACUITY / MUTATION CONTROL (reviewer-run, AC2.5). Point the reconciled
# suite at the pre-removal gate (HEAD = the commit before this step landed):
#
#   d="$(mktemp -d)"; cp -r hooks/scripts/lib "$d/"
#   git show HEAD:hooks/scripts/reviewed-path-gate.sh > "$d/unfixed.sh"
#   GATE_UNDER_TEST="$d/unfixed.sh" bash tests/reviewed-path-gate.test.sh; echo $?
#
# Expected: exit 1 with FAIL lines covering EVERY case 32 blocked form below
# and no case 32 allow-control, each reading rc=0 - the pre-removal gate really
# did allow them. Same two traps as case 30/31's controls: GATE_UNDER_TEST must
# be an ABSOLUTE path or every case reads rc=127, and lib/ must sit beside the
# copy or the gate dies sourcing lib/agent-identity.sh and every case reads
# rc=1.
#
# The bare read (last form below) is included on purpose: it is the cost of
# the removal, ratified here rather than left to look like an oversight.
# Nothing in this case is executed against the network - the suite only ever
# feeds command strings to the gate.
for c in "gh api -X PUT repos/O/R/contents/$marker/9.pass -f message=x -f content=UEFTUwo=" \
         "gh api --method PUT repos/O/R/contents/$marker/9.pass --input body.json" \
         "gh api -X DELETE repos/O/R/contents/$marker/9.pass -f message=x -f sha=abc" \
         "gh api repos/O/R/contents/$marker/9.pass -f content=x" \
         "gh api graphql -f query=$marker" \
         "gh api repos/O/R/contents/$marker/9.pass"; do
  bash_case "case 32 gh api off the allowlist: $c" blocked lead-programmer "$c"
done
# The over-block bound: removing `api` must leave `issue`/`pr`/`search` text
# mentions and read-only inspection untouched.
for c in "gh issue close 9 --comment \"see $marker/9.pass\"" \
         "gh pr comment 9 --body \"see $marker/9.pass\"" \
         "gh search code --filename 9.pass $marker" \
         "cat $marker/9.pass" \
         "grep -r pat $marker"; do
  bash_case "case 32 allow-control: $c" allowed lead-programmer "$c"
done
echo
exit "$fail"

echo
echo "-- path-gate-logs-grant-denied: audit logging for blocked non-reviewer access --"
# Create a fixture with audit log and test grant-denied logging
audit_fixture="$(mk audit-test "$cfg_reviewer")"
audit_log="$audit_fixture/.claude/review-audit.log"
touch "$audit_log"

# Test 1: non-reviewer agent should log grant-denied when blocked
run "$(jq -n --arg a "rev-302" --arg c "printf x > $marker/9.pass" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')" "$audit_fixture"
check "case 33 non-reviewer blocked Bash logs grant-denied" blocked
if [ -s "$audit_log" ] && grep -q "grant-denied.*identity=" "$audit_log"; then
  grant_denied_count=$(grep -c "grant-denied" "$audit_log" 2>/dev/null || true)
  if [ "$grant_denied_count" -eq 1 ]; then
    pass "case 33 grant-denied audit: exactly one grant-denied line logged"
  else
    bad "case 33 grant-denied audit: got $grant_denied_count lines, expected 1"
  fi
else
  bad "case 33 grant-denied audit: no grant-denied line found in audit log"
fi

# Test 2: reviewer agent should NOT log grant-denied (access allowed)
: > "$audit_log"  # Clear the log
run "$(jq -n --arg a "reviewer" --arg c "printf x > $marker/9.pass" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')" "$audit_fixture"
check "case 34 reviewer Bash allowed (no grant-denied logged)" allowed
if grep -q "grant-denied" "$audit_log" 2>/dev/null; then
  bad "case 34 reviewer access: grant-denied should not be logged for allowed access"
else
  pass "case 34 reviewer access: no grant-denied line (as expected)"
fi

# Test 3: mutation control - verify grant-denied is logged only when blocked
run "$(jq -n --arg a "lead-programmer" --arg c "printf x > $marker/9.pass" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')" "$audit_fixture"
: > "$audit_log"  # Reset before checking
check "case 35 lead-programmer also blocked" blocked

