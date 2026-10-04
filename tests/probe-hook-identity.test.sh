#!/usr/bin/env bash
# Offline tests for scripts/probe-hook-identity.sh; claude, tmux and sleep are PATH stubs installed before the first source.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
T="$(mktemp -d)"; trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
mkdir "$T/bin"
printf '#!/bin/sh\ntouch "%s/ran-claude"\necho "claude 0.0.0-stub"\n' "$T" > "$T/bin/claude"
printf '#!/bin/sh\ntouch "%s/ran-tmux"\nexit 0\n' "$T" > "$T/bin/tmux"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/sleep"
chmod +x "$T/bin/"*
export PATH="$T/bin:$PATH" PROBE_SCRATCH="$T/scratch"
SRC="${PROBE_UNDER_TEST:-scripts/probe-hook-identity.sh}"
case $SRC in /*) ;; *) SRC="$PWD/$SRC" ;; esac
# shellcheck disable=SC1090
source "$SRC" "$T/first-rec.md"
set +e
fails=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: got [$2] want [$3]"; fi; }

KM='["cwd","hook_event_name","session_id","tool_input","tool_name","transcript_path"]'
KS='["agent_id","agent_type","cwd","hook_event_name","session_id","tool_input","tool_name","transcript_path"]'
cap() { # event session agent_id_json agent_type_json cmd teams transcript keys_json run
  jq -nc --arg e "$1" --arg s "$2" --argjson a "$3" --argjson t "$4" --arg c "$5" --arg te "$6" --arg tp "$7" --argjson k "$8" --arg r "$9" \
    '{event:$e,keys:$k,agent_id:$a,agent_type:$t,session_id:$s,permission_mode:"default",cmd:(if $c=="" then null else $c end),name:null,transcript_path:$tp,teams_env:$te,run:$r}'
}
tline() { jq -nc --arg c "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Bash",input:{command:$c}}]}}'; }
te() { printf '%s' "${ALLTE-$1}"; }

# scen <teammate agent_id json> <teammate agent_type json> <teammate teams_env> <teammate keys json>
# knobs: NOMAIN MAIN_AID MAINT_AID SUB_AID MATE_CMD MATE_SID MATE_STOP NOMATE NOSUB NOMT LEAD_RAN_MATE T2(unreadable|empty) ALLTE
scen() {
  W="$(mktemp -d "$T/w.XXXXXX")"
  tline 'echo probe-main' > "$W/t1.jsonl"; tline 'echo probe-main' > "$W/t2.jsonl"
  [ -n "${LEAD_RAN_MATE:-}" ] && tline 'echo probe-teammate' >> "$W/t2.jsonl"
  case "${T2:-}" in unreadable) chmod 000 "$W/t2.jsonl" ;; empty) : > "$W/t2.jsonl" ;; esac
  {
    [ -z "${NOMAIN:-}" ] && cap PreToolUse s1 "${MAIN_AID:-null}" null 'echo probe-main' "$(te '')" "$W/t1.jsonl" "$KM" run1
    [ -z "${NOSUB:-}" ] && cap PreToolUse s1 "${SUB_AID:-\"sa1\"}" '"general-purpose"' 'echo probe-subagent' "$(te '')" "$W/t1.jsonl" "$KS" run1
    cap SubagentStop s1 '"sa1"' '"general-purpose"' "" "$(te '')" "$W/t1.jsonl" "$KS" run1
    cap Stop s1 null null "" "$(te '')" "$W/t1.jsonl" "$KM" run1
    [ -z "${NOMT:-}" ] && cap PreToolUse s2 "${MAINT_AID:-null}" null 'echo probe-main' "$(te 1)" "$W/t2.jsonl" "$KM" run2
    [ -z "${NOMATE:-}" ] && cap PreToolUse "${MATE_SID:-s2}" "$1" "$2" "${MATE_CMD:-echo probe-teammate}" "$(te "$3")" "$W/t2.jsonl" "$4" run2
    [ -n "${MATE_STOP:-}" ] && cap SubagentStop "${MATE_SID:-s2}" "$1" "$2" "" "$(te "$3")" "$W/t2.jsonl" "$KS" run2
    cap Stop s2 null null "" "$(te 1)" "$W/t2.jsonl" "$KM" run2
  } > "$W/cap.jsonl"
  classify_rows "$W/cap.jsonl" > "$W/rows"
  OUTC="$(outcome "$W/rows")"
  TC="$(sed -n 's/^Teammate check: //p' "$W/rows")"
}
noteam() { grep -q '^Identity row: teammate' "$W/rows" && bad "$1 no teammate row" || ok "$1 no teammate row"; }

# (I8) the first source ran neither claude nor tmux
if [ -e "$T/ran-claude" ] || [ -e "$T/ran-tmux" ]; then bad "(I8) sourcing called claude or tmux"; else ok "(I8) sourcing called neither claude nor tmux"; fi

MATE_SID=s3 MATE_STOP=1 scen '"ta1"' '"general-purpose"' 1 "$KS"
eq "(I1) genuine teammate (own session) with agent_id present -> A" "$OUTC" A
eq "(I1) teammate check genuine" "$TC" genuine
grep -qF 'Identity row: subagent agent_id=present agent_type=general-purpose teams_env=unset stop_event=SubagentStop' "$W/rows" && ok "(I1) subagent control row" || bad "(I1) subagent control row"
grep -qF 'Identity row: main agent_id=absent agent_type=absent teams_env=unset stop_event=Stop' "$W/rows" && ok "(I1) main control row" || bad "(I1) main control row"

scen null '"teammate"' 1 "$KM"
eq "(I2) absent agent_id, distinct agent_type -> B" "$OUTC" B
scen null null 1 '["cwd","hook_event_name","session_id","team_name","tool_input","tool_name","transcript_path"]'
eq "(I2b) absent agent_id, teammate-only key -> B" "$OUTC" B
scen null null 1 "$KM"
eq "(I3) indistinguishable, teams_env=1 -> C" "$OUTC" C
scen null null "" "$KM"
eq "(I4) teammate hook did not see teams_env=1 -> D (teams-off; C' folded into D)" "$OUTC" D
eq "(I4) teammate check teams-off" "$TC" teams-off

NOMATE=1 scen null null 1 "$KM"
eq "(I5) no teammate marker line -> D" "$OUTC" D
noteam "(I5)"

MAIN_AID='"weird"' scen null null 1 "$KM"
eq "(I6) main carries agent_id -> X" "$OUTC" X

LEAD_RAN_MATE=1 scen null null 1 "$KM"
eq "(I7) marker in main transcript -> D" "$OUTC" D
noteam "(I7)"

MATE_CMD='echo probe-teammate; true' scen null null 1 "$KM"
eq "(I9) non-exact cmd -> D" "$OUTC" D
noteam "(I9)"

scen null '"x agent_id=present"' 1 "$KM"
[ "$OUTC" != A ] && ok "(I10) hostile agent_type is not A" || bad "(I10) hostile agent_type is not A"
grep -qF 'agent_type=x_agent_id_present ' "$W/rows" && ok "(I10) hostile agent_type sanitized" || bad "(I10) hostile agent_type sanitized"
printf 'Identity row: teammate agent_id=absent agent_type=y teams_env=1 x agent_id=present\n' > "$T/rf.txt"
eq "(I10b) rf reads the first key=value token" "$(rf "$T/rf.txt" teammate agent_id)" absent

ALLTE=0 scen null null 1 "$KM"
eq "(I11) accidental run (teams_env 0 everywhere) -> D" "$OUTC" D
eq "(I11) teammate check teams-off" "$TC" teams-off
has_row "$W/rows" main && has_row "$W/rows" main-teams && ok "(I11) main and main-teams rows found by run" || bad "(I11) main and main-teams rows found by run"

MAINT_AID='"weird"' scen null null 1 "$KM"
eq "(I12) main-teams carries agent_id -> X" "$OUTC" X

MATE_STOP=1 scen '"ta1"' '"general-purpose"' 1 "$KS"
eq "(I13) subagent-shaped teammate -> check" "$TC" subagent-shaped
noteam "(I13)"
eq "(I13) subagent-shaped teammate -> D" "$OUTC" D

NOSUB=1 scen null null 1 "$KM"
eq "(I14) no subagent row -> U" "$OUTC" U

SUB_AID=null scen null null 1 "$KM"
eq "(I15) subagent agent_id absent -> X" "$OUTC" X

if [ "$(id -u)" = 0 ]; then echo "SKIP (I16) chmod 000 is readable as root"; else
  T2=unreadable scen null null 1 "$KM"; noteam "(I16)"
fi
T2=empty scen null null 1 "$KM"; noteam "(I16)"

NOMT=1 scen null null 1 "$KM"
noteam "(I17)"
eq "(I17) missing main-teams row -> U" "$OUTC" U
printf 'Identity row: main-teams agent_id=absent agent_type=absent teams_env=1 stop_event=Stop d observed\nIdentity row: subagent agent_id=present agent_type=g teams_env=unset stop_event=none d observed\n' > "$T/nomain.txt"
eq "(I14) missing main row -> U" "$(outcome "$T/nomain.txt")" U
NOMAIN=1 scen null null 1 "$KM"
has_row "$W/rows" subagent && bad "(I17b) no run1 main line -> subagent row withheld" || ok "(I17b) no run1 main line -> subagent row withheld"

eq "(I18) pane_state trust prompt" "$(pane_state $'Do you trust this folder?\n❯ 1. Yes')" trust
eq "(I18) pane_state ready" "$(pane_state '❯')" ready
eq "(I18) pane_state empty" "$(pane_state '')" wait

M="$(cap PreToolUse s2 '"ta1"' null 'echo probe-teammate' 1 x "$KS" run2-tmux)"
S="$(cap SubagentStop s2 '"ta1"' null '' 1 x "$KS" run2-tmux)"
O="$(cap SubagentStop s2 '"other"' null '' 1 x "$KS" run2-tmux)"
printf '%s\n' "$M" > "$T/d1"; printf '%s\n%s\n' "$M" "$S" > "$T/d2"; printf '%s\n%s\n' "$M" "$O" > "$T/d3"; printf '%s\n%s\n' "$S" "$M" > "$T/d4"
teammate_done "$T/d1"; eq "(I19) marker with no stop -> 1" "$?" 1
teammate_done "$T/d2"; eq "(I19) marker then matching stop -> 0" "$?" 0
teammate_done "$T/d3"; eq "(I19) stop with another agent_id -> 1" "$?" 1
teammate_done "$T/d4"; eq "(I19) stop before the marker -> 1" "$?" 1
teammate_done "$T/d2" run2; eq "(I19) run filter matches -> 0" "$?" 0
teammate_done "$T/d2" run1; eq "(I19) run filter excludes -> 1" "$?" 1
L="$(cap PreToolUse s9 null null 'echo probe-main' 1 x "$KM" run2-tmux)"
LM="$(cap PreToolUse s9 null null 'echo probe-teammate' 1 x "$KM" run2-tmux)"
LS="$(cap Stop s9 null null '' 1 x "$KM" run2-tmux)"
printf '%s\n%s\n%s\n' "$L" "$LM" "$LS" > "$T/d5"
teammate_done "$T/d5" run2-tmux; eq "(I19) lead's own marker then the lead's Stop -> 1" "$?" 1

mkdir "$T/other"
eq "(I20) relative record path becomes absolute" "$(cd "$T/other"; source "$SRC" rel.md; echo "$REC")" "$T/other/rel.md"

mt="$(method_text)"
for w in permission_mode '`name`' '`run`' subagent-shaped; do
  case $mt in *"$w"*) ok "(I21) method_text names $w" ;; *) bad "(I21) method_text names $w" ;; esac
done
mkdir -p "$SCRATCH"; : > "$SCRATCH/rows.txt"; : > "$CAP"
REC="$T/rec21/r.md"; TMUX_RETRY="ran (subagent-shaped)"; ROWS=$'Teammate check: subagent-shaped\n'; OUT=D
write_record
eq "(I21) record has exactly one Tmux retry line" "$(grep -c '^Tmux retry:' "$REC")" 1
grep -qF 'Teammate check: subagent-shaped.' "$REC" && ok "(I21) Status names the check value" || bad "(I21) Status names the check value"

(setup && setup_run run2 1 && echo '{"hook_event_name":"Stop","session_id":"z"}' | .claude/capture.sh) >/dev/null 2>&1
eq "(I22) setup_run sets env teams=1 in project settings" "$(jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' "$SCRATCH/.claude/settings.json" 2>/dev/null)" 1
eq "(I22) capture hook stamps the run id" "$(jq -r '.run' "$CAP" 2>/dev/null)" run2

# (I23-I25) genuineness edges on a raw capture: teammate line in the lead's session, with/without its stop, extra keys
KX='["agent_id","agent_type","cwd","hook_event_name","session_id","team_name","tool_input","tool_name","transcript_path"]'
rawcap() { # file teammate-keys with-stop(0|1) [extra pre-lines file]
  { cap PreToolUse s1 null null 'echo probe-main' "" x "$KM" run1
    cap PreToolUse s1 '"sa1"' '"g"' 'echo probe-subagent' "" x "$KS" run1
    cap PreToolUse s2 null null 'echo probe-main' 1 x "$KM" run2
    cap PreToolUse s2 '"ta1"' '"g"' 'echo probe-teammate' 1 x "$2" run2
    [ "$3" = 1 ] && cap SubagentStop s2 '"ta1"' '"g"' "" 1 x "$KS" run2
  } > "$1"
}
rawcap "$T/r23" "$KS" 0; teammate_choose "$T/r23"
eq "(I23) agent_id in lead session without a stop line -> genuine" "$TCHECK" genuine
rawcap "$T/r24" "$KX" 1; teammate_choose "$T/r24"
eq "(I24) extra key the subagent control lacks -> genuine" "$TCHECK" genuine
{ rawcap "$T/r25a" "$KS" 1; cat "$T/r25a"
  cap PreToolUse s9 '"tb"' '"g"' 'echo probe-teammate' 1 x "$KS" run2-tmux
  cap PreToolUse s9 null null 'echo probe-main' 1 x "$KM" run2-tmux; } > "$T/r25"
teammate_choose "$T/r25"
eq "(I25) a later genuine candidate beats an earlier subagent-shaped one" "$TCHECK" genuine

# (I26-I31) tmux-retry runs: headless run2 gives a subagent-shaped teammate (the retry trigger); <fn> adds the run2-tmux lines
tmuxscen() { # fn
  W="$(mktemp -d "$T/w.XXXXXX")"
  tline 'echo probe-main' > "$W/t1.jsonl"; tline 'echo probe-main' > "$W/t2.jsonl"; tline 'echo probe-main' > "$W/t9.jsonl"
  [ -n "${LEAD_RAN_MATE:-}" ] && tline 'echo probe-teammate' >> "$W/t9.jsonl"
  { cap PreToolUse s1 null null 'echo probe-main' "" "$W/t1.jsonl" "$KM" run1
    cap PreToolUse s1 '"sa1"' '"general-purpose"' 'echo probe-subagent' "" "$W/t1.jsonl" "$KS" run1
    cap SubagentStop s1 '"sa1"' '"general-purpose"' "" "" "$W/t1.jsonl" "$KS" run1
    cap PreToolUse s2 null null 'echo probe-main' 1 "$W/t2.jsonl" "$KM" run2
    cap PreToolUse s2 '"ta1"' '"general-purpose"' 'echo probe-teammate' 1 "$W/t2.jsonl" "$KS" run2
    cap SubagentStop s2 '"ta1"' '"general-purpose"' "" 1 "$W/t2.jsonl" "$KS" run2
    "$1"
  } > "$W/cap.jsonl"
  classify_rows "$W/cap.jsonl" > "$W/rows"
  OUTC="$(outcome "$W/rows")"
  TC="$(sed -n 's/^Teammate check: //p' "$W/rows")"
}
lead_main() { cap PreToolUse s9 null null 'echo probe-main' 1 "$W/t9.jsonl" "$KM" run2-tmux; }
lead_mate() { cap PreToolUse s9 null null 'echo probe-teammate' 1 "$W/t9.jsonl" "$KM" run2-tmux; }
sub_mate() { cap PreToolUse s9 '"tb"' '"general-purpose"' 'echo probe-teammate' 1 "$W/t9.jsonl" "$KS" run2-tmux
  cap SubagentStop s9 '"tb"' '"general-purpose"' "" 1 "$W/t9.jsonl" "$KS" run2-tmux; }
x_i() { lead_mate; }
x_ic() { lead_main; lead_mate; }
x_ii() { sub_mate; }
x_pair() { lead_main; sub_mate; }
x_nullsid() { lead_main | jq -c '.session_id=null'; sub_mate; }
x_real() { lead_main; cap PreToolUse s8 '"tc"' '"general-purpose"' 'echo probe-teammate' 1 "$W/t8.jsonl" "$KS" run2-tmux; }
LEAD_RAN_MATE=1 tmuxscen x_i
[ "$TC" != genuine ] && ok "(I26) tmux lead runs the marker, its run has no main line -> not genuine" || bad "(I26) tmux lead runs the marker, its run has no main line -> not genuine"
noteam "(I26)"; eq "(I26) -> D" "$OUTC" D
LEAD_RAN_MATE=1 tmuxscen x_ic
noteam "(I26c) control: tmux run has its main line, the lead's transcript shows the marker"; eq "(I26c) -> D" "$OUTC" D
tmuxscen x_ii
[ "$TC" != genuine ] && ok "(I27) subagent in s9, tmux run has no main line -> not genuine" || bad "(I27) subagent in s9, tmux run has no main line -> not genuine"
noteam "(I27)"; eq "(I27) -> D" "$OUTC" D
tmuxscen x_pair
eq "(I28) tmux teammate is paired with its own run's lead -> check" "$TC" subagent-shaped
noteam "(I28)"; eq "(I28) -> D" "$OUTC" D
tmuxscen x_nullsid
[ "$TC" != genuine ] && ok "(I29) own run's lead line has no session_id -> not genuine" || bad "(I29) own run's lead line has no session_id -> not genuine"
noteam "(I29)"; eq "(I29) -> D" "$OUTC" D
tmuxscen x_real
eq "(I30) genuine tmux teammate in its own session -> check" "$TC" genuine
eq "(I30) -> A" "$OUTC" A
NOMT=1 scen null null 1 "$KM"
eq "(I31b) no main-teams line -> no-lead" "$TC" no-lead
MATE_STOP=1 scen null null 1 "$KM"
eq "(I31) no agent_id is never subagent-shaped, even beside a null-agent SubagentStop" "$TC" genuine

# (I32-I36) tmux_retry_summary reports the tmux run's own capture, never the headless run2 check
x_none() { :; }
tmuxscen x_none
S="$(tmux_retry_summary "$W/cap.jsonl")"
case $S in *'0 run2-tmux capture lines'*) ok "(I32a) no run2-tmux lines -> says 0 run2-tmux capture lines" ;; *) bad "(I32a) got [$S]" ;; esac
case $S in *subagent-shaped*) bad "(I32a) run2's subagent-shaped leaked into the summary: [$S]" ;; *) ok "(I32a) run2's subagent-shaped not reported" ;; esac
eq "(I32) zero-capture summary text" "$S" "ran: 0 run2-tmux capture lines; nothing captured"
tmuxscen x_pair
eq "(I33) pair: own count and check" "$(tmux_retry_summary "$W/cap.jsonl")" "ran: 3 run2-tmux capture lines; teammate check: subagent-shaped"
tmuxscen x_real
eq "(I34) genuine tmux teammate: own count and check" "$(tmux_retry_summary "$W/cap.jsonl")" "ran: 2 run2-tmux capture lines; teammate check: genuine"
tmuxscen lead_main
eq "(I35) tmux lines but no teammate candidate -> check none" "$(tmux_retry_summary "$W/cap.jsonl")" "ran: 1 run2-tmux capture lines; teammate check: none"
tmuxscen x_real
TCHECK=sentinel; tmux_retry_summary "$W/cap.jsonl" >/dev/null
eq "(I35b) summary does not clobber TCHECK" "$TCHECK" sentinel
mkdir -p "$RAW" "$SCRATCH"; : > "$SCRATCH/rows.txt"; : > "$CAP"; printf 'PANE-LINE-XYZ\n' > "$RAW/teammate-tmux.txt"
REC="$T/rec36/r.md"; write_record
grep -qF '### tmux retry pane' "$REC" && grep -qF 'PANE-LINE-XYZ' "$REC" && ok "(I36) record appendix carries the tmux pane" || bad "(I36) record appendix carries the tmux pane"
rm -f "$RAW/teammate-tmux.txt"; REC="$T/rec36b/r.md"; write_record
grep -qF '### tmux retry pane' "$REC" && bad "(I36b) no pane file -> no pane section" || ok "(I36b) no pane file -> no pane section"

# (I37) mutation: the old pre-run text ran ($TCHECK) must fail the zero-capture case
MUT="$T/mut/scripts/probe-hook-identity.sh"; mkdir -p "$T/mut/scripts"
python3 - "$PWD/scripts/probe-hook-identity.sh" "$MUT" <<'PY'
import re,sys
s=open(sys.argv[1]).read()
m=re.search(r'tmux_retry_summary\(\) \{.*?\n\}\n', s, re.S)
assert m
s=s[:m.start()]+'tmux_retry_summary() { printf "ran (%s)" "$TCHECK"; }\n'+s[m.end():]
open(sys.argv[2],'w').write(s)
PY
if [ -z "${PROBE_MUTANT:-}" ]; then
  MOUT="$(PROBE_MUTANT=1 PROBE_UNDER_TEST="$MUT" bash "$PWD/tests/probe-hook-identity.test.sh" 2>&1)"
  case $MOUT in *'FAIL (I32a)'*) ok "(I37) mutant ran (\$TCHECK) fails case (I32a)" ;; *) bad "(I37) mutant survives" ;; esac
fi

[ "$fails" -eq 0 ]
