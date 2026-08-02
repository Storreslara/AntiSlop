#!/usr/bin/env bash
# Behavioral fixture suite for hooks/scripts/dispatch-hygiene.sh. Canned
# hook-input JSON piped over stdin, project dirs seeded under mktemp -d - no
# claude CLI, no live agent dispatch. Plugin hooks load from the installed
# marketplace cache rather than this working tree (R4), so this suite is the
# only admissible evidence the hook works.
#
# Fixture hygiene: every fixture sets testAndLintCommand to "true", NEVER this
# repo's `bash tests/validate.sh` - this suite runs FROM validate.sh, so
# inheriting it would recurse. Every .pass marker is seeded under the case's own
# temp dir; this repo's reviewer-owned .claude/reviewed/ is never touched.
#
# Thresholds are pinned per fixture rather than inherited from the shipped
# defaults, so recalibrating the defaults can never silently un-test a case.
# T20 is the one deliberate exception - it exists to pin the defaults.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

hook=hooks/scripts/dispatch-hygiene.sh

make_project() {
  # $1 = case name, $2 = dispatchHygiene object JSON ("" omits it entirely)
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  if [ -n "$2" ]; then
    printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true","dispatchHygiene":%s}\n' \
      "$2" > "$dir/.claude/persona-config.json"
  else
    printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' \
      > "$dir/.claude/persona-config.json"
  fi
  echo "$dir"
}

payload() {
  # $1 = subagent_type, $2 = prompt
  jq -n --arg s "$1" --arg p "$2" \
    '{tool_name:"Agent",tool_input:{subagent_type:$s,prompt:$p}}'
}

run() {
  # $1 = project dir, $2 = stdin payload -> sets $rc and $err (stderr only)
  rc=0
  err="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$hook" 2>&1 >/dev/null)" || rc=$?
}

ok()  { echo "OK   $1"; }
bad() { echo "FAIL $1"; fail=1; }

xbytes() { head -c "$1" /dev/zero | tr '\0' x; }

fenced() {
  # $1 = interior line count -> a prompt carrying one ``` fenced block
  local n="$1" i out
  out=$'Please review the attached snippet.\n```\n'
  for ((i = 1; i <= n; i++)); do out+="line $i"$'\n'; done
  out+=$'```\nThat is all.\n'
  printf '%s' "$out"
}

contract() {
  # $1 = unit id -> a fully compliant nine-element dispatch prompt (Step 3's
  # contract). Deliberately terse: H4 checks labels, not substance, so the
  # thinnest possible body that carries all nine markers is the honest fixture.
  printf 'Unit: %s\n\n## Objective\nLand the thing.\n\n## Retrieval\nGitHub issues, gh CLI.\n\n## Affected files\n- lib/foo.sh (anchor: main())\n\n## Ordered edits\n1. Edit lib/foo.sh at main().\n\n## Do NOT touch\n- every other path.\n\n## Acceptance criteria\n- bash -n lib/foo.sh -> exit 0\n\n## Pre-resolved context\nTDD applies; extend tests/foo.test.sh.\n\n## Escalation\nIf any instruction cannot be followed exactly as written, STOP.\n' "$1"
}

# A prompt carrying none of the nine markers. Reused by T24/T25/T26.
naked=$'Please go and implement the thing we discussed.\n'

# T1 - non-Agent tool is not our business.
dir="$(make_project t1 '{"maxPromptBytes":1000,"maxInlineBlockLines":20}')"
run "$dir" "$(jq -n --arg p "$(xbytes 2000)" '{tool_name:"Bash",tool_input:{prompt:$p}}')"
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T1 tool_name=Bash -> exit 0, nothing logged"
else
  bad "T1 expected exit 0 and no audit log (rc=$rc)"
fi

# T2 - Agent spawn carrying no prompt at all.
dir="$(make_project t2 '{"maxPromptBytes":1000,"maxInlineBlockLines":20}')"
run "$dir" '{"tool_name":"Agent","tool_input":{"subagent_type":"lead-programmer"}}'
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T2 no .tool_input.prompt -> exit 0, nothing logged"
else
  bad "T2 expected exit 0 and no audit log (rc=$rc)"
fi

# T3 - unadapted project. The prompt would breach the shipped default, so an
# exit 0 here can only come from the missing-config early exit.
dir="$tmproot/t3"; mkdir -p "$dir/.claude"
run "$dir" "$(payload lead-programmer "$(xbytes 31000)")"
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T3 no persona-config.json -> exit 0, nothing logged"
else
  bad "T3 expected exit 0 and no audit log (rc=$rc)"
fi

# T4 - mode off disarms the gate entirely.
dir="$(make_project t4 '{"mode":"off","maxPromptBytes":1000,"maxInlineBlockLines":20}')"
run "$dir" "$(payload lead-programmer "$(xbytes 51200)")"
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T4 mode=off with a 50 KB prompt -> exit 0, nothing logged"
else
  bad "T4 expected exit 0 and no audit log (rc=$rc)"
fi

# requireContract is pinned false throughout T5-T21 for the same reason the
# thresholds are pinned: these cases exist to measure H1/H2/H3, and every one of
# them dispatches a deliberately non-contract prompt to the gated target, so a
# default-on H4 would fire alongside the check under test and decide the exit
# code for it. Their assertions are unchanged.
h1_cfg_block='{"mode":"block","maxPromptBytes":1000,"maxInlineBlockLines":200,"requireContract":false}'
h1_cfg_warn='{"mode":"warn","maxPromptBytes":1000,"maxInlineBlockLines":200,"requireContract":false}'

# T5 - H1 blocks, names its own limit, and logs.
dir="$(make_project t5 "$h1_cfg_block")"
run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"
if [ "$rc" = 2 ] && grep -q '1000-byte limit' <<< "$err" \
   && grep -q 'blocked=H1 target=lead-programmer' "$dir/.claude/dispatch-audit.log"; then
  ok "T5 H1 oversize under mode=block -> exit 2, stderr names the limit, blocked= logged"
else
  bad "T5 expected exit 2 + '1000-byte limit' on stderr + blocked=H1 (rc=$rc)"
fi

# T6 - same breach under warn: advisory only.
dir="$(make_project t6 "$h1_cfg_warn")"
run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"
if [ "$rc" = 0 ] && [ -n "$err" ] \
   && grep -q 'warned=H1 target=lead-programmer' "$dir/.claude/dispatch-audit.log"; then
  ok "T6 H1 oversize under mode=warn -> exit 0, stderr non-empty, warned= logged"
else
  bad "T6 expected exit 0 + non-empty stderr + warned=H1 (rc=$rc)"
fi

h2_cfg='{"maxPromptBytes":30000,"maxInlineBlockLines":20,"requireContract":false}'

# T7 - H2 fires on an over-wide fenced block, and it is H2 that fires, not H1.
dir="$(make_project t7 "$h2_cfg")"
run "$dir" "$(payload lead-programmer "$(fenced 30)")"
log="$dir/.claude/dispatch-audit.log"
if [ "$rc" = 2 ] && grep -q 'blocked=H2 target=lead-programmer' "$log" \
   && ! grep -q 'blocked=H1' "$log"; then
  ok "T7 H2 30-line fenced block over a 20-line limit -> exit 2, blocked=H2 only"
else
  bad "T7 expected exit 2 + blocked=H2 without blocked=H1 (rc=$rc)"
fi

# T8 - H2 negative: a block under the limit is fine.
dir="$(make_project t8 "$h2_cfg")"
run "$dir" "$(payload lead-programmer "$(fenced 10)")"
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T8 H2 10-line fenced block under a 20-line limit -> exit 0, nothing logged"
else
  bad "T8 expected exit 0 and no audit log (rc=$rc)"
fi

h3_cfg='{"maxPromptBytes":30000,"maxInlineBlockLines":200,"requireContract":false}'
unit148=$'Unit: 148\nPlease finish the remaining acceptance criteria.\n'

# T9 - H3 refuses to re-dispatch a unit that already holds a PASS marker.
dir="$(make_project t9 "$h3_cfg")"
: > "$dir/.claude/reviewed/148.pass"
run "$dir" "$(payload lead-programmer "$unit148")"
if [ "$rc" = 2 ] && grep -q 'blocked=H3 target=lead-programmer' "$dir/.claude/dispatch-audit.log"; then
  ok "T9 H3 re-dispatch of a PASSed unit -> exit 2, blocked=H3 logged"
else
  bad "T9 expected exit 2 + blocked=H3 (rc=$rc)"
fi

# T10 - H3 negative: a non-gated target is never inspected.
dir="$(make_project t10 "$h3_cfg")"
: > "$dir/.claude/reviewed/148.pass"
run "$dir" "$(payload explorer "$unit148")"
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T10 H3 with a non-gated target (explorer) -> exit 0, nothing logged"
else
  bad "T10 expected exit 0 and no audit log (rc=$rc)"
fi

# T11 - H3 negative: no marker, no opinion (H3 fails open by construction).
dir="$(make_project t11 "$h3_cfg")"
run "$dir" "$(payload lead-programmer $'Unit: 149\nStart the next unit.\n')"
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T11 H3 with no .pass marker for the named unit -> exit 0, nothing logged"
else
  bad "T11 expected exit 0 and no audit log (rc=$rc)"
fi

# T12 - H3 negative: gated target, but the prompt carries no Unit: line.
dir="$(make_project t12 "$h3_cfg")"
: > "$dir/.claude/reviewed/148.pass"
run "$dir" "$(payload lead-programmer $'Please tidy up the helper in lib/foo.sh.\n')"
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T12 gated target with no Unit: line at all -> exit 0, nothing logged"
else
  bad "T12 expected exit 0 and no audit log (rc=$rc)"
fi

# T13 - the gate compares agent IDENTITIES, not bare strings: a namespaced
# subagent_type must still match the bare gatedAgents entry.
dir="$(make_project t13 "$h3_cfg")"
: > "$dir/.claude/reviewed/148.pass"
run "$dir" "$(payload antislop:lead-programmer "$unit148")"
if [ "$rc" = 2 ] \
   && grep -q 'blocked=H3 target=antislop:lead-programmer' "$dir/.claude/dispatch-audit.log"; then
  ok "T13 namespaced antislop:lead-programmer is gated -> exit 2, blocked=H3 logged"
else
  bad "T13 expected exit 2 + blocked=H3 for the namespaced identity (rc=$rc)"
fi

# T14 - escape hatch with a reason: honoured, logged, and single-use.
dir="$(make_project t14 "$h1_cfg_block")"
printf 'override: intentional bulk paste\n' > "$dir/.claude/.dispatch-override"
run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"
log="$dir/.claude/dispatch-audit.log"
if [ "$rc" = 0 ] && [ ! -e "$dir/.claude/.dispatch-override" ] \
   && grep -q 'override=intentional bulk paste target=lead-programmer' "$log" \
   && ! grep -q 'blocked=' "$log"; then
  ok "T14 .dispatch-override with a reason -> exit 0, override= logged, sentinel consumed"
else
  bad "T14 expected exit 0 + override= logged + sentinel deleted (rc=$rc)"
fi

# T15 - reason-less escape hatch: consumed but NOT honoured.
dir="$(make_project t15 "$h1_cfg_block")"
: > "$dir/.claude/.dispatch-override"
run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"
log="$dir/.claude/dispatch-audit.log"
if [ "$rc" = 2 ] && [ ! -e "$dir/.claude/.dispatch-override" ] \
   && grep -q 'blocked=H1 target=lead-programmer' "$log" \
   && ! grep -q 'override=' "$log"; then
  ok "T15 empty .dispatch-override -> exit 2, sentinel deleted, blocked= logged"
else
  bad "T15 expected exit 2 + sentinel deleted + blocked=H1 and no override= (rc=$rc)"
fi

# T16 - a malformed payload must fail open, never abort a dispatch.
dir="$(make_project t16 "$h1_cfg_block")"
run "$dir" '{"tool_name": "Agent", "tool_input": {"prompt": '
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T16 malformed JSON on stdin -> exit 0, nothing logged"
else
  bad "T16 expected exit 0 and no audit log (rc=$rc)"
fi

# T17 - the #155 defect shape. First non-blank line names an un-PASSed unit; a
# PASSed unit's id is quoted, unindented, deep inside a fenced block. A scan
# that inspects every line exits 2 here; a first-line-scoped one exits 0.
t17_prompt="Unit: 900"$'\n\nThe dispatch convention, quoted from the spec:\n\n'
for i in $(seq 1 30); do t17_prompt+="context line $i"$'\n'; done
t17_prompt+=$'```\nUnit: 148\nPlease finish the remaining acceptance criteria.\n```\n'
t17_prompt+=$'Follow that shape for this unit.\n'
dir="$(make_project t17 "$h3_cfg")"
: > "$dir/.claude/reviewed/148.pass"
run "$dir" "$(payload lead-programmer "$t17_prompt")"
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T17 PASSed unit id quoted in the body, not on the first line -> exit 0, nothing logged"
else
  bad "T17 whole-body scan regression: expected exit 0 and no audit log (rc=$rc)"
fi

# T18 - a Unit: line that is present but not first. The convention is "opens
# with", so a non-conforming prompt is treated as carrying no Unit: line
# (OQ3 fail-open). Catches the other whole-body-scan flavour, "first matching
# line anywhere", which T17 cannot see.
t18_prompt=$'Please implement the following:\n\nHere is the work.\nUnit: 148\nGo ahead.\n'
dir="$(make_project t18 "$h3_cfg")"
: > "$dir/.claude/reviewed/148.pass"
run "$dir" "$(payload lead-programmer "$t18_prompt")"
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T18 Unit: line present but not the first non-blank line -> exit 0, nothing logged"
else
  bad "T18 whole-body scan regression: expected exit 0 and no audit log (rc=$rc)"
fi

# T19 - path traversal rejected (R5). Four sub-cases; (c) and (d) are what make
# this discriminating, because (a) and (b) name markers that do not exist under
# any grammar, so both a safe and an unsafe script exit 0 on them.
dir="$(make_project t19ab "$h3_cfg")"
run "$dir" "$(payload lead-programmer $'Unit: ../../../../etc/passwd\nDo the thing.\n')"
rc_a="$rc"
run "$dir" "$(payload lead-programmer $'Unit: ..\nDo the thing.\n')"
if [ "$rc_a" = 0 ] && [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T19 (a)(b) traversal ids ../../../../etc/passwd and .. -> exit 0, nothing logged"
else
  bad "T19 (a)(b) expected exit 0 for both and no audit log (rc_a=$rc_a rc_b=$rc)"
fi

# T19 (c) - a marker seeded OUTSIDE the fixture's own reviewed/ directory, one
# level up, reachable only by traversal. A grammar that lets `../escaped`
# through resolves to it and exits 2, so exit 0 here is observable evidence the
# id was rejected. The control run proves H3 is armed in this very fixture, so
# the exit 0 cannot be a dead check.
dir="$(make_project t19c "$h3_cfg")"
: > "$dir/.claude/escaped.pass"
: > "$dir/.claude/reviewed/inside.pass"
run "$dir" "$(payload lead-programmer $'Unit: ../escaped\nDo the thing.\n')"
rc_esc="$rc"
log_absent=0; [ -f "$dir/.claude/dispatch-audit.log" ] || log_absent=1
run "$dir" "$(payload lead-programmer $'Unit: inside\nDo the thing.\n')"
if [ "$rc_esc" = 0 ] && [ "$log_absent" = 1 ] && [ "$rc" = 2 ] \
   && grep -q 'blocked=H3' "$dir/.claude/dispatch-audit.log"; then
  ok "T19 (c) ../escaped cannot reach a marker above reviewed/ (control: inside -> exit 2)"
else
  bad "T19 (c) expected exit 0 + no log for ../escaped, exit 2 for the control (rc_esc=$rc_esc log_absent=$log_absent rc_ctl=$rc)"
fi

# T19 (d) - the id grammar demands an alphanumeric FIRST character, so a
# dotfile id is rejected before the path is ever built. Widening the character
# class alone - without touching the redundant literal guard, which sees no `/`
# and no `..` here - is caught only by this sub-case.
dir="$(make_project t19d "$h3_cfg")"
: > "$dir/.claude/reviewed/.escaped.pass"
run "$dir" "$(payload lead-programmer $'Unit: .escaped\nDo the thing.\n')"
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T19 (d) leading-dot id .escaped is rejected by the grammar -> exit 0, nothing logged"
else
  bad "T19 (d) id grammar widened: expected exit 0 and no audit log (rc=$rc)"
fi

# T20 - the shipped defaults are live. dispatchHygiene is absent entirely, so
# this pins maxPromptBytes 30000 AND the on-by-default block posture (OQ1).
# Being the one case that pins defaults, it is also the one case that cannot pin
# requireContract false; instead both prompts are padded-out CONTRACT-COMPLIANT
# ones, so default-on H4 stays silent and the exit codes below are decided by
# H1's threshold alone. (requireContract's own default is pinned by T25.)
dir="$(make_project t20 '')"
t20_base="$(contract 900)"
run "$dir" "$(payload lead-programmer "${t20_base}$(xbytes $((29000 - ${#t20_base})))")"
rc_under="$rc"
log_absent=0; [ -f "$dir/.claude/dispatch-audit.log" ] || log_absent=1
run "$dir" "$(payload lead-programmer "${t20_base}$(xbytes $((31000 - ${#t20_base})))")"
if [ "$rc_under" = 0 ] && [ "$log_absent" = 1 ] && [ "$rc" = 2 ] \
   && grep -q 'blocked=H1 target=lead-programmer' "$dir/.claude/dispatch-audit.log"; then
  ok "T20 defaults live: 29000 bytes -> exit 0, 31000 bytes -> exit 2 + blocked=H1"
else
  bad "T20 expected exit 0 at 29000 and exit 2 + blocked=H1 at 31000 (rc_under=$rc_under log_absent=$log_absent rc_over=$rc)"
fi

# T21 - "first non-blank line", not "byte 0".
dir="$(make_project t21 "$h3_cfg")"
: > "$dir/.claude/reviewed/148.pass"
run "$dir" "$(payload lead-programmer $'\n\nUnit: 148\nPlease finish it.\n')"
if [ "$rc" = 2 ] && grep -q 'blocked=H3 target=lead-programmer' "$dir/.claude/dispatch-audit.log"; then
  ok "T21 two leading newlines before Unit: 148 -> exit 2, blocked=H3 logged"
else
  bad "T21 expected exit 2 + blocked=H3 despite the leading blank lines (rc=$rc)"
fi

h4_cfg='{"mode":"block","maxPromptBytes":30000,"maxInlineBlockLines":200,"requireContract":true}'

# T22 - H4 blocks a gated dispatch missing ONE marker, and names it. The
# excluded checks matter: H4 must be the sole reason this exits 2.
dir="$(make_project t22 "$h4_cfg")"
run "$dir" "$(payload lead-programmer "$(contract 300 | grep -v '^## Escalation$')")"
log="$dir/.claude/dispatch-audit.log"
if [ "$rc" = 2 ] && grep -q 'blocked=H4 target=lead-programmer' "$log" \
   && ! grep -qE 'blocked=H[123]' "$log" && grep -q '## Escalation' <<< "$err"; then
  ok "T22 gated dispatch missing '## Escalation' -> exit 2, blocked=H4, stderr names it"
else
  bad "T22 expected exit 2 + blocked=H4 alone + '## Escalation' on stderr (rc=$rc)"
fi

# T23 - the positive half of the pair: all nine markers present -> silence. Same
# config as T22, so the only difference between the two is the contract itself.
dir="$(make_project t23 "$h4_cfg")"
run "$dir" "$(payload lead-programmer "$(contract 301)")"
if [ "$rc" = 0 ] && [ ! -f "$dir/.claude/dispatch-audit.log" ]; then
  ok "T23 gated dispatch carrying all nine markers -> exit 0, nothing logged"
else
  bad "T23 expected exit 0 and no audit log (rc=$rc err=$err)"
fi

# T24 - a non-gated spawn is never inspected. The control run sends the SAME
# naked prompt to the gated target: without it this case is green even if H4
# never fires at all.
dir="$(make_project t24 "$h4_cfg")"
run "$dir" "$(payload scribe "$naked")"
rc_scribe="$rc"
log_absent=0; [ -f "$dir/.claude/dispatch-audit.log" ] || log_absent=1
run "$dir" "$(payload lead-programmer "$naked")"
if [ "$rc_scribe" = 0 ] && [ "$log_absent" = 1 ] && [ "$rc" = 2 ] \
   && grep -q 'blocked=H4 target=lead-programmer' "$dir/.claude/dispatch-audit.log"; then
  ok "T24 naked prompt to scribe -> exit 0 (control: same prompt to lead-programmer -> exit 2)"
else
  bad "T24 expected exit 0 + no log for scribe, exit 2 + blocked=H4 for the control (rc_scribe=$rc_scribe log_absent=$log_absent rc_ctl=$rc)"
fi

# T25 - the opt-out genuinely disarms H4. The control omits dispatchHygiene
# entirely, which pins requireContract's ON-BY-DEFAULT posture and simultaneously
# proves the opt-out run above was not just an accidentally-compliant prompt.
dir="$(make_project t25 '{"maxPromptBytes":30000,"maxInlineBlockLines":200,"requireContract":false}')"
run "$dir" "$(payload lead-programmer "$naked")"
rc_off="$rc"
log_absent=0; [ -f "$dir/.claude/dispatch-audit.log" ] || log_absent=1
dir="$(make_project t25ctl '')"
run "$dir" "$(payload lead-programmer "$naked")"
if [ "$rc_off" = 0 ] && [ "$log_absent" = 1 ] && [ "$rc" = 2 ] \
   && grep -q 'blocked=H4 target=lead-programmer' "$dir/.claude/dispatch-audit.log"; then
  ok "T25 requireContract=false -> exit 0 (control: key absent defaults ON -> exit 2)"
else
  bad "T25 expected exit 0 + no log when opted out, exit 2 + blocked=H4 by default (rc_off=$rc_off log_absent=$log_absent rc_ctl=$rc)"
fi

# T26 - H4 honours mode=warn like every other check.
dir="$(make_project t26 '{"mode":"warn","maxPromptBytes":30000,"maxInlineBlockLines":200,"requireContract":true}')"
run "$dir" "$(payload lead-programmer "$naked")"
log="$dir/.claude/dispatch-audit.log"
if [ "$rc" = 0 ] && [ -n "$err" ] && grep -q 'warned=H4 target=lead-programmer' "$log" \
   && ! grep -q 'blocked=' "$log"; then
  ok "T26 H4 under mode=warn -> exit 0, stderr non-empty, warned=H4 logged"
else
  bad "T26 expected exit 0 + non-empty stderr + warned=H4 and no blocked= (rc=$rc)"
fi

# T27 - MUTATION CONTROL for the whole H4 group. T22's exit 2 is only evidence
# if H4's fire call is what produced it; a mis-wired check that blocked for some
# other reason would leave T22 green forever. Neuter `fire H4` in a throwaway
# copy and confirm T22's scenario flips to exit 0. The copy takes lib/ with it -
# a mutant that dies at startup exits non-zero on EVERY case and would otherwise
# read as a successful kill.
mutant_dir="$tmproot/t27bin"
mkdir -p "$mutant_dir"
cp "$hook" "$mutant_dir/dispatch-hygiene.sh"
cp -r hooks/scripts/lib "$mutant_dir/lib"
mutant="$mutant_dir/dispatch-hygiene.sh"
sed -i 's/^\([[:space:]]*\)fire H4 /\1: /' "$mutant"
dir="$(make_project t27 "$h4_cfg")"
t27_prompt="$(contract 300 | grep -v '^## Escalation$')"
hook_real="$hook"; hook="$mutant"
run "$dir" "$(payload lead-programmer "$t27_prompt")"
rc_mutant="$rc"
log_absent=0; [ -f "$dir/.claude/dispatch-audit.log" ] || log_absent=1
# ...and the mutant must still be a working script, or the exit 0 above is just
# a broken file. H1 is untouched by the mutation, so it still blocks.
run "$dir" "$(payload lead-programmer "$(xbytes 31000)")"
rc_alive="$rc"
hook="$hook_real"
run "$dir" "$(payload lead-programmer "$t27_prompt")"
if ! grep -q 'fire H4 ' "$mutant" && [ "$rc_mutant" = 0 ] && [ "$log_absent" = 1 ] \
   && [ "$rc_alive" = 2 ] && [ "$rc" = 2 ]; then
  ok "T27 mutation control: neutered fire H4 -> the missing-marker prompt passes (mutant still alive; real hook still blocks)"
else
  bad "T27 mutation control failed: expected mutated=yes rc_mutant=0 log_absent=1 rc_alive=2 rc_real=2 (got rc_mutant=$rc_mutant log_absent=$log_absent rc_alive=$rc_alive rc_real=$rc)"
fi

# T28 - Sequential double-fire honours both: a prompt that would breach H1,
# with the override sentinel in place, is run twice consecutively. Both should
# exit 0. Baseline (prior to the fix): first rc=0, second rc=2.
dir="$(make_project t28 "$h1_cfg_block")"
printf 'override: double-fire test\n' > "$dir/.claude/.dispatch-override"
run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"
rc_first="$rc"
consumed_exists=0; [ -f "$dir/.claude/.dispatch-override.consumed" ] && consumed_exists=1
sentinel_exists=0; [ -f "$dir/.claude/.dispatch-override" ] && sentinel_exists=1
# Second fire uses the stamp now (not a fresh sentinel).
run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"
rc_second="$rc"
log="$dir/.claude/dispatch-audit.log"
if [ "$rc_first" = 0 ] && [ "$consumed_exists" = 1 ] && [ "$sentinel_exists" = 0 ] \
   && [ "$rc_second" = 0 ] \
   && grep -q 'override=double-fire test target=lead-programmer' "$log" \
   && grep -q 'override-replay=double-fire test target=lead-programmer' "$log"; then
  ok "T28 sequential double-fire honours both, writes and replays stamp"
else
  bad "T28 expected rc_first=0 rc_second=0 with consumed stamp and both audit lines (rc_first=$rc_first consumed=$consumed_exists sentinel=$sentinel_exists rc_second=$rc_second)"
fi

# T29 - Parallel double-fire honours both, 20/20 trials. Two backgrounded runs
# per trial, both should exit 0. This stress-tests race conditions around stamp
# creation and reading.
dir="$(make_project t29 "$h1_cfg_block")"
passed_trials=0
for trial in $(seq 1 20); do
  printf 'override: parallel-fire test\n' > "$dir/.claude/.dispatch-override"
  # Clear any stale consumed stamp from the prior trial.
  rm -f "$dir/.claude/.dispatch-override.consumed"

  # Two parallel runs, each in its own subshell.
  rc_a=0; rc_b=0
  (run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"; exit "$rc") &
  pid_a=$!
  (run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"; exit "$rc") &
  pid_b=$!

  wait "$pid_a" || rc_a=$?
  wait "$pid_b" || rc_b=$?

  if [ "$rc_a" = 0 ] && [ "$rc_b" = 0 ]; then
    passed_trials=$((passed_trials + 1))
  fi
done

if [ "$passed_trials" = 20 ]; then
  ok "T29 parallel double-fire honours both, 20/20 trials"
else
  bad "T29 expected 20/20 trials to have both exit 0 (got $passed_trials/20)"
fi

# T30 - No widening: a consumed stamp applies only to the exact same dispatch
# (same prompt). A dispatch with a one-character-different prompt must exit 2.
dir="$(make_project t30 "$h1_cfg_block")"
printf 'override: widening-test\n' > "$dir/.claude/.dispatch-override"
# First fire with prompt1.
prompt1="$(xbytes 2048)"
run "$dir" "$(payload lead-programmer "$prompt1")"
rc_first="$rc"
# Stamp is now consumed. Try a second fire with a slightly different prompt.
prompt2="${prompt1}x"
run "$dir" "$(payload lead-programmer "$prompt2")"
rc_different="$rc"
log="$dir/.claude/dispatch-audit.log"
if [ "$rc_first" = 0 ] && [ "$rc_different" = 2 ] \
   && grep -q 'override=widening-test target=lead-programmer' "$log" \
   && grep -q 'blocked=H1 target=lead-programmer' "$log"; then
  ok "T30 no widening: different payload exits 2, same check blocks"
else
  bad "T30 expected rc_first=0 rc_different=2 with override= and blocked=H1 (rc_first=$rc_first rc_different=$rc_different)"
fi

# T31 - Window expiry: if the consumed stamp's epoch is backdated past the
# 10-second window, a replay of the same payload must exit 2.
dir="$(make_project t31 "$h1_cfg_block")"
printf 'override: expiry-test\n' > "$dir/.claude/.dispatch-override"
payload_t31="$(xbytes 2048)"
run "$dir" "$(payload lead-programmer "$payload_t31")"
rc_first="$rc"
# Backdate the consumed stamp to 11 seconds ago.
if [ -f "$dir/.claude/.dispatch-override.consumed" ]; then
  current_epoch=$(date +%s 2>/dev/null || echo 0)
  old_epoch=$((current_epoch - 11))
  consumed_line="$(head -n 1 "$dir/.claude/.dispatch-override.consumed")"
  # Extract the key and reason from the consumed stamp.
  consumed_rest="${consumed_line#* }"
  consumed_key="${consumed_rest%% *}"
  consumed_reason="${consumed_rest#* }"
  printf '%s %s %s\n' "$old_epoch" "$consumed_key" "$consumed_reason" > "$dir/.claude/.dispatch-override.consumed"
fi
# Second fire with the same payload should be blocked by H1 (expiry deletes the stamp).
run "$dir" "$(payload lead-programmer "$payload_t31")"
rc_expired="$rc"
log="$dir/.claude/dispatch-audit.log"
if [ "$rc_first" = 0 ] && [ "$rc_expired" = 2 ] \
   && grep -q 'blocked=H1 target=lead-programmer' "$log"; then
  ok "T31 window expiry: stale stamp deleted, replay blocked by H1"
else
  bad "T31 expected rc_first=0 rc_expired=2 with blocked=H1 (rc_first=$rc_first rc_expired=$rc_expired)"
fi

# T32 - Audit distinguishes the two: after a sequential double-fire (per T28),
# the log must contain exactly one override= and one override-replay= entry
# (both for the same dispatch).
dir="$(make_project t32 "$h1_cfg_block")"
printf 'override: audit-test\n' > "$dir/.claude/.dispatch-override"
run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"
run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"
log="$dir/.claude/dispatch-audit.log"
override_count=0; [ -f "$log" ] && override_count=$(grep -c 'override=' "$log" || true)
replay_count=0; [ -f "$log" ] && replay_count=$(grep -c 'override-replay=' "$log" || true)
if [ "$override_count" = 1 ] && [ "$replay_count" = 1 ]; then
  ok "T32 audit distinguishes override= (1) from override-replay= (1)"
else
  bad "T32 expected override_count=1 replay_count=1 (got override=$override_count replay=$replay_count)"
fi

# T33 - MUTATION CONTROL for the double-fire fix. Disable the replay path
# in a throwaway copy and confirm T28/T29 fail. The mutation: comment out
# the exit 0 that honours the replay, so it falls through to normal checks.
# Criteria 3 and 4 must FAIL with the mutation.
mutant_dir="$tmproot/t33bin"
mkdir -p "$mutant_dir"
cp "$hook" "$mutant_dir/dispatch-hygiene.sh"
cp -r hooks/scripts/lib "$mutant_dir/lib"
mutant_t33="$mutant_dir/dispatch-hygiene.sh"
# Disable the replay path by commenting out the exit 0 after override-replay honour.
# This ensures the replay path doesn't actually exit, so it falls through.
sed -i '/log_line "override-replay=/,/exit 0/ s/^\([[:space:]]*\)exit 0/\1: # exit 0/' "$mutant_t33"
dir="$(make_project t33 "$h1_cfg_block")"
printf 'override: mutation-test\n' > "$dir/.claude/.dispatch-override"

hook_real="$hook"; hook="$mutant_t33"
# First fire should still work (sentinel path is unchanged).
run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"
rc_mut_first="$rc"
# Second fire should fail with mutant (replay path exits 0 is disabled).
run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"
rc_mut_second="$rc"
hook="$hook_real"
# Confirm the mutation is actually in place (exit 0 after override-replay is commented).
is_mutated=0; grep -q ': # exit 0' "$mutant_t33" && is_mutated=1

if [ "$is_mutated" = 1 ] && [ "$rc_mut_first" = 0 ] && [ "$rc_mut_second" = 2 ]; then
  ok "T33 mutation control: disabling replay exit causes second fire to be blocked (first=0 second=2)"
else
  bad "T33 mutation control: expected is_mutated=1 rc_mut_first=0 rc_mut_second=2 (got mutated=$is_mutated rc_first=$rc_mut_first rc_second=$rc_mut_second)"
fi

# T34 - #220 defect 1 regression: a malformed consumed stamp whose first
# token is a bare non-numeric identifier must never abort the hook under
# set -u arithmetic expansion. Baseline (pre-fix): rc=1 (aborted, gate
# disarmed, H1-H4 skipped, nothing logged). Fixed: rc=2 (blocked normally,
# stamp ignored).
dir="$(make_project t34 "$h4_cfg")"
printf 'x k r\n' > "$dir/.claude/.dispatch-override.consumed"
run "$dir" "$(payload lead-programmer "$naked")"
if [ "$rc" = 2 ]; then
  ok "T34 malformed consumed stamp (non-numeric epoch) -> exit 2, not an unbound-variable abort"
else
  bad "T34 expected exit 2 for a malformed stamp, not an abort (rc=$rc)"
fi

# T35 - #220 defect 2 regression: an unrelated dispatch inside the replay
# window must not destroy a live sibling's stamp. P (oversize, honoured) ->
# Q (unrelated prompt, any rc) -> re-dispatch of P inside the window must
# still be honoured as a replay (rc=0), not blocked (rc=2).
dir="$(make_project t35 "$h1_cfg_block")"
printf 'override: key-mismatch test\n' > "$dir/.claude/.dispatch-override"
prompt_p="$(xbytes 2048)"
run "$dir" "$(payload lead-programmer "$prompt_p")"
rc_p_first="$rc"
run "$dir" "$(payload lead-programmer "unrelated dispatch prompt")"
run "$dir" "$(payload lead-programmer "$prompt_p")"
rc_p_replay="$rc"
if [ "$rc_p_first" = 0 ] && [ "$rc_p_replay" = 0 ]; then
  ok "T35 unrelated in-window dispatch does not destroy a live sibling's replay stamp"
else
  bad "T35 expected rc_p_first=0 rc_p_replay=0 (got rc_p_first=$rc_p_first rc_p_replay=$rc_p_replay)"
fi

# T36 - the identity key now binds subagent_type: the SAME prompt sent to a
# DIFFERENT gated-or-not target is never honoured as a replay of the first.
dir="$(make_project t36 "$h1_cfg_block")"
printf 'override: target-binding test\n' > "$dir/.claude/.dispatch-override"
prompt_shared="$(xbytes 2048)"
run "$dir" "$(payload lead-programmer "$prompt_shared")"
rc_first_target="$rc"
run "$dir" "$(payload scribe "$prompt_shared")"
rc_other_target="$rc"
if [ "$rc_first_target" = 0 ] && [ "$rc_other_target" = 2 ]; then
  ok "T36 same prompt to a different subagent_type is not a valid replay"
else
  bad "T36 expected rc_first_target=0 rc_other_target=2 (got first=$rc_first_target other=$rc_other_target)"
fi

# T37 - near-boundary: a stamp backdated close to (but safely inside) the
# 10-second edge is still honoured (pairs with T31's 11-second expiry case,
# which fails from the other flank, to pin the documented [-2, +10] span
# rather than leaving it merely asserted in prose). Backdating by exactly 10
# is NOT used here: `date +%s` has 1-second granularity, and the second
# `run` call itself costs real wall-clock time, so an exact-10 backdate is a
# coin flip against a second boundary ticking over mid-test (observed
# directly: this failed intermittently at rc=2 when written that way).
# Backdating by 8 (computed from the STAMP's own epoch, not a fresh `date`
# call, to avoid compounding drift on the write side too) leaves 2 full
# seconds of slack against that same source of flakiness while still
# demonstrating the window extends meaningfully past a single-digit
# same-second window.
dir="$(make_project t37 "$h1_cfg_block")"
printf 'override: boundary-test\n' > "$dir/.claude/.dispatch-override"
prompt_t37="$(xbytes 2048)"
run "$dir" "$(payload lead-programmer "$prompt_t37")"
rc_boundary_first="$rc"
if [ -f "$dir/.claude/.dispatch-override.consumed" ]; then
  consumed_line="$(head -n 1 "$dir/.claude/.dispatch-override.consumed")"
  stamp_epoch="${consumed_line%% *}"
  consumed_rest="${consumed_line#* }"
  old_epoch=$((stamp_epoch - 8))
  printf '%s %s\n' "$old_epoch" "$consumed_rest" > "$dir/.claude/.dispatch-override.consumed"
fi
run "$dir" "$(payload lead-programmer "$prompt_t37")"
rc_boundary_replay="$rc"
if [ "$rc_boundary_first" = 0 ] && [ "$rc_boundary_replay" = 0 ]; then
  ok "T37 a stamp backdated 8 seconds (near the window's upper edge) is still honoured"
else
  bad "T37 expected rc_boundary_first=0 rc_boundary_replay=0 (got first=$rc_boundary_first replay=$rc_boundary_replay)"
fi

# T38 - MUTATION CONTROL for the reorder root cause itself: revert the
# write-stamp-before-delete-sentinel ordering back to delete-then-write (the
# pre-fix shape) in a throwaway copy, and confirm the parallel race
# reproduces. T29 alone cannot see this regression (both processes there
# take the sentinel-consumption path, never the replay path); this mutant
# targets the ordering directly.
#
# The NATURAL race window between the reordered rm and the write is a few
# microseconds, so measuring it via unstaggered concurrent trials (as an
# earlier version of this test did) is a coin flip: at the ~5-6% per-trial
# failure rate independently measured against the true pre-fix hook (19/20,
# 47/50), 20 unstaggered trials land on a false all-honoured 20/20 roughly
# 1 time in 3 (0.94^20). Instead, widen the mutant's window with an
# artificial `sleep` between the delete and the write - this cannot mask a
# real bug (a correctly-ordered hook has no such gap to widen) and turns the
# same race into a 100%-reproducible one, at the cost of also needing a
# staggered dispatch (mirroring T39) to land inside it. Verified directly:
# 20/20 trials of this staggered pair against the mutant show B blocked,
# and 20/20 of the identical staggered pair against the REAL hook show both
# honoured (the control below), so the assertion isolates the reorder, not
# an artifact of staggered timing.
mutant_dir="$tmproot/t38bin"
mkdir -p "$mutant_dir"
cp "$hook" "$mutant_dir/dispatch-hygiene.sh"
cp -r hooks/scripts/lib "$mutant_dir/lib"
mutant_t38="$mutant_dir/dispatch-hygiene.sh"
sed -i -e '/^[[:space:]]*rm -f "\$override"$/d' \
       -e '/^[[:space:]]*consumed_tmp="\${consumed}\.tmp/i\
rm -f "$override"\
sleep 0.3' \
  "$mutant_t38"
rm_line="$(grep -n '^[[:space:]]*rm -f "\$override"$' "$mutant_t38" | head -1 | cut -d: -f1)"
tmp_line="$(grep -n '^[[:space:]]*consumed_tmp="\${consumed}\.tmp' "$mutant_t38" | head -1 | cut -d: -f1)"
order_ok=0
[ -n "$rm_line" ] && [ -n "$tmp_line" ] && [ "$rm_line" -lt "$tmp_line" ] && order_ok=1

dir="$(make_project t38 "$h1_cfg_block")"
printf 'override: reorder-mutant test\n' > "$dir/.claude/.dispatch-override"
hook_real="$hook"; hook="$mutant_t38"
rc_a=0; rc_b=0
(run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"; exit "$rc") &
pid_a=$!
(sleep 0.1; run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"; exit "$rc") &
pid_b=$!
wait "$pid_a" || rc_a=$?
wait "$pid_b" || rc_b=$?
hook="$hook_real"

# Control: the SAME staggered pair against the REAL hook, proving the
# blocked outcome above is attributable to the reorder, not the staggering.
dir_ctl="$(make_project t38ctl "$h1_cfg_block")"
printf 'override: reorder-control test\n' > "$dir_ctl/.claude/.dispatch-override"
rc_ctl_a=0; rc_ctl_b=0
(run "$dir_ctl" "$(payload lead-programmer "$(xbytes 2048)")"; exit "$rc") &
pid_ctl_a=$!
(sleep 0.1; run "$dir_ctl" "$(payload lead-programmer "$(xbytes 2048)")"; exit "$rc") &
pid_ctl_b=$!
wait "$pid_ctl_a" || rc_ctl_a=$?
wait "$pid_ctl_b" || rc_ctl_b=$?

if [ "$order_ok" = 1 ] && [ "$rc_a" = 0 ] && [ "$rc_b" = 2 ] \
   && [ "$rc_ctl_a" = 0 ] && [ "$rc_ctl_b" = 0 ]; then
  ok "T38 mutation control: widened delete-before-write reorder deterministically blocks the staggered sibling (control: real hook honours both)"
else
  bad "T38 mutation control failed: expected order_ok=1 rc_a=0 rc_b=2 rc_ctl_a=0 rc_ctl_b=0 (got order_ok=$order_ok rc_a=$rc_a rc_b=$rc_b rc_ctl_a=$rc_ctl_a rc_ctl_b=$rc_ctl_b)"
fi

# T39 - forces the REPLAY branch itself to fire in a genuinely concurrent
# (backgrounded) dispatch, which T29 does not: T29's two processes both
# measure at the sentinel-consumption branch (10/10 override=, 0/10
# override-replay= per the #220 review), so the replay path stays
# unexercised by a parallel case. Here B's own hook invocation is staggered
# by a sleep well inside its own backgrounded subshell (a shorter delay than
# the write+delete sequence needs is not enough; 0.3s is ample and still far
# under the 10s window) so A deterministically finishes writing the stamp
# and deleting the sentinel first, and B is forced onto the .consumed stamp.
# Both are still dispatched via `&`, not sequentially.
dir="$(make_project t39 "$h1_cfg_block")"
printf 'override: staggered-parallel test\n' > "$dir/.claude/.dispatch-override"
rc_a=0; rc_b=0
(run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"; exit "$rc") &
pid_a=$!
(sleep 0.3; run "$dir" "$(payload lead-programmer "$(xbytes 2048)")"; exit "$rc") &
pid_b=$!
wait "$pid_a" || rc_a=$?
wait "$pid_b" || rc_b=$?
log="$dir/.claude/dispatch-audit.log"
if [ "$rc_a" = 0 ] && [ "$rc_b" = 0 ] \
   && grep -q 'override=staggered-parallel test target=lead-programmer' "$log" \
   && grep -q 'override-replay=staggered-parallel test target=lead-programmer' "$log"; then
  ok "T39 staggered parallel dispatch forces the replay branch to actually fire"
else
  bad "T39 expected rc_a=0 rc_b=0 with both override= and override-replay= logged (rc_a=$rc_a rc_b=$rc_b)"
fi

exit "$fail"
