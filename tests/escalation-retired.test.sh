#!/usr/bin/env bash
# Escalation machinery is retired from prose; the reviewer's optional needs-human note replaces it.
set -u
cd "$(dirname "$0")/.."
mode="${1:-}"
case "$mode" in prose|code-hdg) ;; *) echo "usage: escalation-retired.test.sh prose|code-hdg" >&2; exit 2 ;; esac
fail=0
bad() { echo "FAIL $*"; fail=1; }
if [ "$mode" = code-hdg ]; then
  gate=hooks/scripts/human-decision-gate.sh
  [ "$(wc -l < "$gate")" -le 15 ] || bad "$gate is longer than 15 lines"
  # the decision path is assembled from pieces so this file never spells it whole
  dpath=".claude/human-re""view/u1/DEC""ISION"
  bashp=$(jq -n --arg c "printf approve > $dpath" '{tool_name:"Bash",agent_type:"lead-programmer",tool_input:{command:$c}}')
  writep=$(jq -n --arg p "$dpath" '{tool_name:"Write",agent_type:"lead-programmer",tool_input:{file_path:$p,content:"approve"}}')
  for payload in "$bashp" "$writep"; do
    rc=0; out=$(printf '%s' "$payload" | bash "$gate" 2>&1) || rc=$?
    [ "$rc" = 0 ] || bad "gate exits $rc on a decision-file write, want 0"
    [ -z "$out" ] || bad "gate prints output on a decision-file write"
  done
  cmp -s "$gate" ".claude/$gate" || bad ".claude/$gate differs from $gate"
  for f in tests/human-decision-gate"".test.sh tests/hdg-differential""-sweep.sh; do
    [ ! -e "$f" ] || bad "$f still exists"
  done
  for f in tests/validate.sh tests/watch-map.json; do
    ! grep -q 'human-decision-gate.test' "$f" || bad "$f still names the deleted suite"
  done
  n=$(grep -c 'human-decision-gate.sh' hooks/hooks.json || true)
  [ "$n" = 2 ] || bad "hooks/hooks.json names the gate $n times, want 2"
  exit "$fail"
fi
# each pattern is assembled from pieces so this file never spells one whole
pats=(
  "[Ee][Ss][Cc][Aa][Ll][Aa][Tt][Ee]-[Tt][Oo]""-[Hh][Uu][Mm][Aa][Nn]"
  "\\.escal""ated\\b"
  "human-re""view/"
  "(/DEC""ISION|\`DEC""ISION\`|DEC""ISION file|DEC""ISION <task-id>)"
  "escalation""-card"
  "heavy""-trigger"
  "human-decision""-gate"
  "decision-gate"" denial"
  "Fourth"" verdict"
  "[Ee]scalation"" packet"
)
for p in "${pats[@]}"; do
  if hits=$(git grep -nE -e "$p" -- agents templates commands skills adapters ':!adapters/*/hooks/**'); then
    printf '%s\n' "$hits"; fail=1
  fi
done
for f in agents/reviewer.md agents/orchestrator.md; do
  grep -q 'needs-human:' "$f" || { echo "missing needs-human: in $f"; fail=1; }
done
exit "$fail"
