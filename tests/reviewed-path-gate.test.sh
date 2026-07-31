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
  for t in T1 T2 T3 T4 T5; do
    case "$t" in
      T1) payload="ls $marker$byte#x; rm -f $marker/9.pass" ;;        # comment word-start predecessor
      T2) payload="ls $marker #x${byte}rm -f $marker/9.pass" ;;       # comment terminator
      T3) payload="ls $marker >&1$byte$marker/9.pass" ;;              # fd-exemption trailing anchor
      T4) payload="ls $marker >/dev/null$byte$marker/9.pass" ;;       # /dev/null-exemption trailing anchor
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
# the assertion that fails instead. Measured on the fixed gate: 255 of 635.
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
echo "-- case 28: exhaustive flag-boundary byte sweep (G,R x 0x01-0x7F) --"
# The flag scans in program_allowed() modelled a bash word boundary as one
# literal space, which is narrower than bash's own rule - the third bug of that
# class in this file (#177, #182, and this one). Cases 29.a-29.o below pin the
# named forms, but example-based fixtures are exactly what let the first two
# land, so this pins the boundary predicate ITSELF: every byte 0x01-0x7F, no
# exclusions, crossed with the two templates, asserted as a SET EQUALITY. A byte
# blocked that is not on the expected list fails just as loudly as one on the
# list that is allowed, so the fix cannot be over-corrected into an over-block
# either.
#
# REAL-BASH DIFFERENTIAL HALF, on template G. An earlier draft of this case had
# none, on the stated ground that `git diff --output=F` outside a git repository
# "writes nothing (measured: rc 128/129)". The rc was right and the conclusion
# was wrong: git parses --output and OPENS the target before it ever discovers
# there is no repository, so the file is TRUNCATED TO 0 BYTES and then the run
# exits 129. Measured directly (git 2.43.0), which is why the sentinel here is
# checked for content and not merely for existence. Had that claim gone in
# unverified, this case would have been exactly the vacuous differential it was
# written to avoid. (`git log --output=F` really does write nothing - rc 128,
# file untouched - so the distinction is per-subcommand, not per-flag.)
#
# MUTATION CONTROL (reviewer-run, AC1.9). Revert the scan to matching the RAW
# segment - i.e. strip quote deletion and metacharacter normalization out of
# flag_scan_form(), leaving it a bare padder, which is precisely the pre-fix
# literal-space check. Copy lib/ alongside the mutant: the gate sources
# lib/agent-identity.sh relative to its OWN path, so a bare copy dies at startup
# and every case "fails" with rc=1, which looks like a kill but proves nothing.
#
#   d="$(mktemp -d)"; cp -r hooks/scripts/lib "$d/"
#   sed -e 's/^  local s=.*/  local s="$1"/' -e '/^  s="/d' \
#     hooks/scripts/reviewed-path-gate.sh > "$d/mutant.sh"
#   GATE_UNDER_TEST="$d/mutant.sh" bash tests/reviewed-path-gate.test.sh; echo $?
#
# Measured: exit 1, 18 FAIL lines - case 28 G and R each at bytes 0x09, 0x28,
# 0x29 and 0x3C, all nine of 29.a-29.i, and one DIFFERENTIAL line ("real bash
# altered or removed the sentinel") at G byte 0x09, which is the half below
# catching a live filesystem effect rather than a predicate disagreement. The
# floor required by AC1.9 is >= 6, with >= 1 from G, >= 1 from R and >= 4 from
# case 29. Read the rc on those FAIL lines: rc=0 means the gate ALLOWED a payload
# it should have blocked, which is the kill; rc=1 means the mutant crashed and
# the run is void.
#
# MUTATION CONTROL 2 (reviewer-run, AC1.9-R), for the EXPANSION refusal, which
# mutant 1 above does not touch at all. Drop the refusal line only:
#
#   d="$(mktemp -d)"; cp -r hooks/scripts/lib "$d/"
#   sed '/^  case "\$1" in \*\[/d' \
#     hooks/scripts/reviewed-path-gate.sh > "$d/mutant2.sh"
#   GATE_UNDER_TEST="$d/mutant2.sh" bash tests/reviewed-path-gate.test.sh; echo $?
#
# Measured: exit 1, 18 FAIL lines - case 28 G and R each at the six expansion
# bytes (0x24 0x2A 0x3F 0x5B 0x7B 0x7E), cases 29.j-29.n, and 29.o flipping to
# allowed. Every one reads rc=0, not rc=1. Note the two mutants are disjoint:
# neither one's kill set overlaps the other's, which is what shows the expansion
# refusal is an independent third mechanism and not a restatement of the first two.
#
# THE EXPECTED SET. Ten bash metacharacters; four bytes the pre-existing
# skeletonizer and substitution scan reject on their own (0x22 " 0x27 ' 0x5C \
# 0x60 `); and six EXPANSION characters refused by flag_scan_form (0x24 $
# 0x2A * 0x3F ? 0x5B [ 0x7B { 0x7E ~) - 0x60 ` belongs to both groups. VT 0x0B,
# FF 0x0C and CR 0x0D are deliberately NOT here (ordinary word characters to
# bash), and neither is 0x7D } - `{` alone already catches brace expansion, so
# blocking its partner would be an over-block with nothing to show for it.
expect_blocked=" 0x09 0x0A 0x20 0x22 0x24 0x26 0x27 0x28 0x29 0x2A 0x3B 0x3C 0x3E 0x3F 0x5B 0x5C 0x60 0x7B 0x7C 0x7E "
sweep_g_executed=0
for t in G R; do
  diverged=0
  for ((b = 1; b <= 127; b++)); do
    byte="$(printf "\\$(printf '%03o' "$b")"; printf .)"
    byte="${byte%.}"
    hex="$(printf '0x%02X' "$b")"
    case "$t" in
      G) payload="git diff HEAD$byte--output=$marker/9.pass" ;;
      R) payload="rg pat $marker$byte--pre=/bin/sh" ;;
    esac
    bash_run "$payload"
    # Exact codes, so a crashing gate (rc=1 under set -e) can never be counted
    # as a block and silently satisfy the expected set.
    if [ "$rc" = 2 ] && [ -s "$errf" ]; then verdict=blocked
    elif [ "$rc" = 0 ]; then verdict=allowed
    else verdict="rc=$rc"
    fi
    case "$expect_blocked" in
      *" $hex "*) want=blocked ;;
      *)          want=allowed ;;
    esac
    if [ "$verdict" != "$want" ]; then
      diverged=$((diverged + 1))
      bad "case 28 $t byte $hex: $verdict, expected $want"
    fi
    # Differential half: only ever for a payload the gate ALLOWED, so any effect
    # on the marker directory is a fail-open by definition. G only - template R
    # invokes rg, whose --pre runs a command but writes nothing under the marker
    # directory, so an R differential would be inert by construction and would
    # assert coverage it does not have (case 26's T3/T4 mistake). Stated rather
    # than quietly omitted.
    if [ "$t" = G ] && [ "$verdict" = allowed ]; then
      sweep_g_executed=$((sweep_g_executed + 1))
      sweep_differential "28 G" "$hex" "$payload"
    fi
  done
  [ "$diverged" -ne 0 ] || pass "case 28 $t: blocked-byte set is exactly the expected 20 of 127"
done
# Non-vacuity floor for the differential half, mirroring case 26's: if a future
# change blocked everything, nothing would ever be executed and the differential
# would pass for the wrong reason.
if [ "$sweep_g_executed" -ge 100 ]; then
  pass "case 28 differential non-vacuity ($sweep_g_executed allowed G payloads executed against real bash >= 100)"
else
  bad "case 28 differential non-vacuity: only $sweep_g_executed G payloads reached real bash (< 100)"
fi

echo
echo "-- case 29: flag tokens at a word boundary, quote-transparently --"
tab="$(printf '\011')"
bash_case "case 29.a git --output preceded by an empty double-quoted string" blocked lead-programmer \
  "git diff \"\"--output=$marker/9.pass HEAD"
bash_case "case 29.b git --output preceded by an empty single-quoted string" blocked lead-programmer \
  "git diff ''--output=$marker/9.pass HEAD"
bash_case "case 29.c git --output split across a quote after the first dash" blocked lead-programmer \
  "git diff -\"-output=$marker/9.pass\" HEAD"
bash_case "case 29.d quote INSIDE the git flag name" blocked lead-programmer \
  "git diff --out\"put\"=$marker/9.pass HEAD"
bash_case "case 29.e git --output after a TAB boundary" blocked lead-programmer \
  "git diff$tab--output=$marker/9.pass HEAD"
bash_case "case 29.f rg --pre preceded by an empty double-quoted string" blocked lead-programmer \
  "rg pat $marker \"\"--pre=/bin/sh"
bash_case "case 29.g rg --pre split across a quote after the first dash" blocked lead-programmer \
  "rg pat $marker -\"-pre\" /bin/sh"
bash_case "case 29.h rg --pre TERMINATED by a TAB, not a space" blocked lead-programmer \
  "rg --pre$tab/bin/sh pat $marker"
bash_case "case 29.i quote INSIDE the rg flag name" blocked lead-programmer \
  "rg --p\"re\"=/bin/sh pat $marker"
# 29.j-29.n: EXPANSION forges a flag token out of text that spells no flag at
# all, so neither a wider boundary set nor quote transparency can see it - only
# refusing the construct can. With E unset, ${E} expands to nothing, and the
# brace forms build `--output`/`--pre` out of a list containing no such
# substring. All five were measured overwriting a seeded target (or, for rg,
# invoking a command) under real bash in a throwaway sandbox.
bash_case "case 29.j empty expansion forges the git flag boundary" blocked lead-programmer \
  "git diff \${E}--output=$marker/9.pass HEAD"
bash_case "case 29.k empty expansion INSIDE the git flag name" blocked lead-programmer \
  "git diff --outpu\${E}t=$marker/9.pass HEAD"
bash_case "case 29.l brace expansion builds the git flag name" blocked lead-programmer \
  "git diff --out{p,p}ut=$marker/9.pass HEAD"
bash_case "case 29.m empty expansion forges the rg flag boundary" blocked lead-programmer \
  "rg pat $marker \${E}--pre=/bin/sh"
bash_case "case 29.n brace expansion builds the rg flag name" blocked lead-programmer \
  "rg pat $marker --p{r,r}e=/bin/sh"
# The over-approximation's upper bound. Quote deletion and metacharacter
# flattening can only ADD word starts, so the risk they carry is over-blocking
# ordinary read-only work; these eight pin that it did not happen. --pretty and
# --pre-glob are the near-misses that must stay allowed, and `git log --oneline`
# is the one that a widened `-o` scan would swallow.
for c in "rg --pretty pat $marker" \
         "git log --oneline -- $marker" \
         "git commit -m \"fix: record the verdict under $marker\"" \
         "git diff --stat HEAD -- $marker" \
         "gh issue close 9 --comment \"see $marker/9.pass\"" \
         "cat $marker/9.pass" \
         "ls -la $marker"; do
  bash_case "case 29 allow-control: $c" allowed lead-programmer "$c"
done
# RATIFIED RESIDUAL (AC1.16). `rg --pre-glob *.md` was an allow-control until the
# expansion refusal landed; the glob `*` now fails the segment closed. Pinned as
# BLOCKED rather than carved out, because a carve-out would have to decide which
# `*` is a glob and which is a forged flag - the same "model one more construct"
# move that produced all three bugs of this class. Documented workaround: quote
# the glob (`rg --pre-glob '*.md'`) - which 29.o pins as still blocked too, since
# quotes are transparent here - or scope the search with a path instead.
bash_case "case 29.o rg --pre-glob's glob fails closed (ratified residual, AC1.16)" \
  blocked lead-programmer "rg --pre-glob *.md pat $marker"

echo
exit "$fail"
