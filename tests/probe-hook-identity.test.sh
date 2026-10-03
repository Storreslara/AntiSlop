#!/usr/bin/env bash
# Offline tests for scripts/probe-hook-identity.sh classify_rows/outcome; never runs claude or tmux.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
SRC="${PROBE_UNDER_TEST:-scripts/probe-hook-identity.sh}"
# shellcheck disable=SC1090
source "$SRC"
set +e
fails=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: got [$2] want [$3]"; fi; }

KM='["cwd","hook_event_name","session_id","tool_input","tool_name","transcript_path"]'
KS='["agent_id","agent_type","cwd","hook_event_name","session_id","tool_input","tool_name","transcript_path"]'
cap() { # event session agent_id_json agent_type_json cmd teams transcript keys_json
  jq -nc --arg e "$1" --arg s "$2" --argjson a "$3" --argjson t "$4" --arg c "$5" --arg te "$6" --arg tp "$7" --argjson k "$8" \
    '{event:$e,keys:$k,agent_id:$a,agent_type:$t,session_id:$s,permission_mode:"default",cmd:(if $c=="" then null else $c end),name:null,transcript_path:$tp,teams_env:$te}'
}
tline() { jq -nc --arg c "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Bash",input:{command:$c}}]}}'; }

# scen <teammate agent_id json> <teammate agent_type json> <teammate teams_env> <teammate keys json>; knobs: MAIN_AID, MATE_CMD, NOMATE, LEAD_RAN_MATE
scen() {
  W="$(mktemp -d)"
  tline 'echo probe-main' > "$W/t1.jsonl"; tline 'echo probe-main' > "$W/t2.jsonl"
  [ -n "${LEAD_RAN_MATE:-}" ] && tline 'echo probe-teammate' >> "$W/t2.jsonl"
  {
    cap PreToolUse s1 "${MAIN_AID:-null}" null 'echo probe-main' "" "$W/t1.jsonl" "$KM"
    cap PreToolUse s1 '"sa1"' '"general-purpose"' 'echo probe-subagent' "" "$W/t1.jsonl" "$KS"
    cap SubagentStop s1 '"sa1"' '"general-purpose"' "" "" "$W/t1.jsonl" "$KS"
    cap Stop s1 null null "" "" "$W/t1.jsonl" "$KM"
    cap PreToolUse s2 null null 'echo probe-main' 1 "$W/t2.jsonl" "$KM"
    [ -z "${NOMATE:-}" ] && cap PreToolUse s2 "$1" "$2" "${MATE_CMD:-echo probe-teammate}" "$3" "$W/t2.jsonl" "$4"
    cap Stop s2 null null "" "" "$W/t2.jsonl" "$KM"
  } > "$W/cap.jsonl"
  classify_rows "$W/cap.jsonl" > "$W/rows"
  OUTC="$(outcome "$W/rows")"
}

scen '"ta1"' '"general-purpose"' 1 "$KS"
eq "(I1) teammate agent_id present -> A" "$OUTC" A
grep -qF 'Identity row: subagent agent_id=present agent_type=general-purpose teams_env=unset stop_event=SubagentStop' "$W/rows" && ok "(I1) subagent control row" || bad "(I1) subagent control row"
grep -qF 'Identity row: main agent_id=absent agent_type=absent teams_env=unset stop_event=Stop' "$W/rows" && ok "(I1) main control row" || bad "(I1) main control row"

scen null '"teammate"' 1 "$KM"
eq "(I2) absent agent_id, distinct agent_type -> B" "$OUTC" B
scen null null 1 '["cwd","hook_event_name","session_id","team_name","tool_input","tool_name","transcript_path"]'
eq "(I2b) absent agent_id, teammate-only key -> B" "$OUTC" B
scen null null 1 "$KM"
eq "(I3) indistinguishable, teams_env=1 -> C" "$OUTC" C
scen null null "" "$KM"
eq "(I4) indistinguishable, teams_env unset -> C'" "$OUTC" "C'"

NOMATE=1 scen null null 1 "$KM"
eq "(I5) no teammate marker line -> D" "$OUTC" D
grep -q '^Identity row: teammate' "$W/rows" && bad "(I5) no teammate row" || ok "(I5) no teammate row"

MAIN_AID='"weird"' scen null null 1 "$KM"
eq "(I6) main carries agent_id -> X" "$OUTC" X

LEAD_RAN_MATE=1 scen null null 1 "$KM"
eq "(I7) marker in main transcript -> D" "$OUTC" D
grep -q '^Identity row: teammate' "$W/rows" && bad "(I7) no teammate row" || ok "(I7) no teammate row"

MATE_CMD='echo probe-teammate; true' scen null null 1 "$KM"
eq "(I9) non-exact cmd -> D" "$OUTC" D
grep -q '^Identity row: teammate' "$W/rows" && bad "(I9) no teammate row" || ok "(I9) no teammate row"

# (I8) sourcing runs neither claude nor tmux
S8="$(mktemp -d)"; mkdir "$S8/bin"
for b in claude tmux; do printf '#!/bin/sh\ntouch "%s/ran"\n' "$S8" > "$S8/bin/$b"; chmod +x "$S8/bin/$b"; done
( PATH="$S8/bin:$PATH"; source "$SRC" "$S8/rec.md" ) >/dev/null 2>&1
if [ -e "$S8/ran" ]; then bad "(I8) sourcing called claude or tmux"; else ok "(I8) sourcing called neither claude nor tmux"; fi

[ "$fails" -eq 0 ]
