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

h1_cfg_block='{"mode":"block","maxPromptBytes":1000,"maxInlineBlockLines":200}'
h1_cfg_warn='{"mode":"warn","maxPromptBytes":1000,"maxInlineBlockLines":200}'

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

h2_cfg='{"maxPromptBytes":30000,"maxInlineBlockLines":20}'

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

h3_cfg='{"maxPromptBytes":30000,"maxInlineBlockLines":200}'
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
dir="$(make_project t20 '')"
run "$dir" "$(payload lead-programmer "$(xbytes 29000)")"
rc_under="$rc"
log_absent=0; [ -f "$dir/.claude/dispatch-audit.log" ] || log_absent=1
run "$dir" "$(payload lead-programmer "$(xbytes 31000)")"
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

exit "$fail"
