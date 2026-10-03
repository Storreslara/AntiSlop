#!/usr/bin/env bash
# Operator probe for esc-followups item 1: which identity fields does a PreToolUse hook see for main, subagent and teammate? Run: bash scripts/probe-hook-identity.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATE="$(date +%F)"
REC="${1:-$ROOT/docs/experiments/$DATE-probe-hook-identity.md}"
SCRATCH=/tmp/hook-identity-probe
CAP="$SCRATCH/capture.jsonl"
RAW="$SCRATCH/raw"
TS="hook-identity-probe-$$"
ACTORS="main main-teams subagent teammate"
ALLOWED='Bash(echo probe-*)'
VERSION="" ; MISSING="" ; OUT="" ; ROWS=""

cleanup() { tmux -L "$TS" kill-server 2>/dev/null; rm -rf "$SCRATCH"; }
tm() { tmux -L "$TS" "$@"; }

setup() {
  rm -rf "$SCRATCH"; mkdir -p "$SCRATCH/.claude" "$RAW"; cd "$SCRATCH" || exit 2
  cat > .claude/capture.sh <<EOH
#!/usr/bin/env bash
jq -c --arg env "\${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" '{event:.hook_event_name, keys:(keys), agent_id:.agent_id, agent_type:.agent_type, session_id:.session_id, permission_mode:.permission_mode, cmd:.tool_input.command, name:.tool_input.name, transcript_path:.transcript_path, teams_env:\$env}' >> $CAP 2>/dev/null
exit 0
EOH
  chmod +x .claude/capture.sh
  jq -n --arg c "$PWD/.claude/capture.sh" '{hooks:{
    PreToolUse:[{matcher:"Bash|Agent",hooks:[{type:"command",command:$c}]}],
    Stop:[{hooks:[{type:"command",command:$c}]}],
    SubagentStop:[{hooks:[{type:"command",command:$c}]}]}}' > .claude/settings.json
  printf '%s\n' 'Do exactly this and nothing else. 1) Run the Bash command `echo probe-main` yourself. 2) Dispatch ONE subagent with the Agent tool, no name, whose entire task is to run the Bash command `echo probe-subagent` and report. Never run `echo probe-subagent` yourself.' > "$RAW/prompt-sub.txt"
  printf '%s\n' 'Do exactly this and nothing else. 1) Run the Bash command `echo probe-main` yourself. 2) Dispatch ONE teammate with the Agent tool using name `probe-mate`, whose entire task is to run the Bash command `echo probe-teammate` and report. Never run `echo probe-teammate` yourself.' > "$RAW/prompt-mate.txt"
  VERSION="$(claude --version 2>&1 | head -1)"
}

# pick <capture> <exact cmd> <teams_env: "" | 1 | any> -> every matching PreToolUse line
pick() {
  jq -c --arg c "$2" --arg t "$3" 'select(.event=="PreToolUse" and .cmd==$c and ($t=="any" or (.teams_env // "")==$t))' "$1" 2>/dev/null
}

actor_line() { # capture actor -> first line for that actor's marker
  case $2 in
    main) pick "$1" 'echo probe-main' '' ;;
    main-teams) pick "$1" 'echo probe-main' 1 ;;
    subagent) pick "$1" 'echo probe-subagent' any ;;
    teammate) pick "$1" 'echo probe-teammate' any ;;
  esac | head -1
}

# a subagent/teammate marker is attributable only if no reference main transcript shows the lead running it
transcript_has() { # transcript cmd -> 0 found, 1 absent, 2 unreadable
  local rc
  [ -s "$1" ] || return 2
  jq -e --arg c "$2" 'select(any(..|objects; .type=="tool_use" and .name=="Bash" and .input.command? == $c))' "$1" >/dev/null 2>&1; rc=$?
  case $rc in 0) return 0 ;; 4) return 1 ;; *) return 2 ;; esac
}

attributable() { # capture actor cmd reference-actor
  local ref="$4" tp rc n=0
  case $2 in main|main-teams) return 0 ;; esac
  while read -r tp; do
    n=$((n + 1)); transcript_has "$tp" "$3"; rc=$?
    [ "$rc" = 1 ] || return 1
  done < <(case $ref in main) pick "$1" 'echo probe-main' '' ;; *) pick "$1" 'echo probe-main' 1 ;; esac | jq -r '.transcript_path' | sort -u)
  [ "$n" -gt 0 ]
}

emit_row() { # capture actor line
  local id ty te se
  id="$(jq -r 'if .agent_id==null then "absent" elif .agent_id=="" then "empty" else "present" end' <<<"$3")"
  ty="$(jq -r 'if .agent_type==null then "absent" elif .agent_type=="" then "empty" else .agent_type end' <<<"$3")"
  te="$(jq -r 'if (.teams_env // "")=="" then "unset" else .teams_env end' <<<"$3")"
  se="$(jq -r --argjson l "$3" 'select((.event=="Stop" or .event=="SubagentStop") and .session_id==$l.session_id and .agent_id==$l.agent_id) | .event' "$1" | head -1)"
  printf 'Identity row: %s agent_id=%s agent_type=%s teams_env=%s stop_event=%s %s observed\n' "$2" "$id" "$ty" "$te" "${se:-none}" "$DATE"
  printf 'Keys row: %s %s\n' "$2" "$(jq -r '.keys | sort | join(" ")' <<<"$3")"
}

classify_rows() { # capture.jsonl -> Identity/Keys rows for every attributable actor
  local a l cmd ref
  for a in $ACTORS; do
    l="$(actor_line "$1" "$a")"; [ -n "$l" ] || continue
    case $a in subagent) cmd='echo probe-subagent'; ref=main ;; teammate) cmd='echo probe-teammate'; ref=main-teams ;; *) cmd=""; ref="" ;; esac
    attributable "$1" "$a" "$cmd" "$ref" || continue
    emit_row "$1" "$a" "$l"
  done
}

rf() { sed -nE "s/^Identity row: $2 (.* )?$3=([^ ]*) .*/\2/p" "$1" | head -1; } # rows-file actor field
has_row() { grep -q "^Identity row: $2 " "$1"; }

controls_ok() { # rows-file: main(+main-teams) show agent_id=absent, subagent shows present
  local f=$1 a
  has_row "$f" main && has_row "$f" subagent || return 1
  [ "$(rf "$f" subagent agent_id)" = present ] || return 1
  for a in main main-teams; do
    if has_row "$f" $a && [ "$(rf "$f" $a agent_id)" != absent ]; then return 1; fi
  done
}

separable() { # rows-file: does any teammate field differ from every main row?
  local f=$1 a tty k u dtype=1
  tty="$(rf "$f" teammate agent_type)"
  for a in main main-teams; do
    if has_row "$f" $a && [ "$tty" = "$(rf "$f" $a agent_type)" ]; then dtype=0; fi
  done
  [ "$dtype" = 1 ] && return 0
  u=" $(sed -nE 's/^Keys row: (main|main-teams) //p' "$f" | tr '\n' ' ') "
  for k in $(sed -nE 's/^Keys row: teammate //p' "$f"); do
    case "$u" in *" $k "*) ;; *) return 0 ;; esac
  done
  return 1
}

outcome() { # rows-file -> exactly one of A B C C' D X
  local f=$1
  controls_ok "$f" || { echo X; return; }
  has_row "$f" teammate || { echo D; return; }
  if [ "$(rf "$f" teammate agent_id)" = present ]; then
    echo A
    return
  fi
  if separable "$f"; then
    echo B
  elif [ "$(rf "$f" teammate teams_env)" = 1 ]; then
    echo C
  else
    echo "C'"
  fi
}

have_marker() { jq -e --arg c "$1" 'select(.event=="PreToolUse" and .cmd==$c)' "$CAP" >/dev/null 2>&1; }

run_headless() { # prompt-file teams-env-value -> one claude -p run in the scratch dir
  ( cd "$SCRATCH" && CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="$2" timeout 180 claude -p "$(cat "$1")" --allowedTools "$ALLOWED" Agent >> "$RAW/$3.txt" 2>&1 )
}

retry_teammate_tmux() {
  local i
  tm new-session -d -s mate -x 200 -y 60 -c "$SCRATCH" "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --allowedTools '$ALLOWED' Agent"
  for ((i = 0; i < 30; i++)); do tm capture-pane -p -t mate 2>/dev/null | grep -q '^❯' && break; sleep 1; done
  sleep 2
  tm load-buffer -b mate "$RAW/prompt-mate.txt"; tm paste-buffer -p -b mate -t mate; sleep 1
  tm send-keys -t mate Enter
  for ((i = 0; i < 180; i++)); do have_marker 'echo probe-teammate' && break; sleep 1; done
  tm capture-pane -p -S - -t mate > "$RAW/teammate-tmux.txt" 2>/dev/null
  tm kill-session -t mate
}

method_text() {
  printf 'The script builds a scratch dir outside the repo whose `.claude/settings.json` registers one capture hook on `PreToolUse` (matcher `Bash|Agent`), `Stop` and `SubagentStop`. The hook appends one JSON line per event to `capture.jsonl` (event, sorted payload keys, `agent_id`, `agent_type`, `session_id`, `transcript_path`, the command, and the hook-visible `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`), prints nothing and always exits 0. Run 1 is `claude -p` with `--allowedTools '"'"'%s'"'"' Agent`: the main session runs `echo probe-main` and dispatches one unnamed subagent that runs `echo probe-subagent`. Run 2 is the same with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and a named `Agent` dispatch (`probe-mate`) that runs `echo probe-teammate`; the main marker in this run is the `main-teams` control. If no teammate marker line was captured after run 2, the script retries once in a detached tmux interactive session with the same env var, waiting up to 180 s. A row is written only when a PreToolUse(Bash) line has a command exactly equal to the marker. For subagent and teammate the row is also withheld unless every reference main transcript (`main` for subagent, `main-teams` for teammate) is readable and holds no Bash `tool_use` of that marker, because otherwise the lead may have run it itself. `stop_event` is the `Stop`/`SubagentStop` line with the same `session_id` and `agent_id`, else `none`. `Outcome:` is the pure `outcome()` function over the rows: `X` if a control fails (main or main-teams `agent_id` not absent, subagent not present, or a control row missing), `D` with no teammate row, `A` if the teammate `agent_id` is present, `B` if it is absent/empty but `agent_type` differs from every main row or a payload key appears that no main row has, else `C` when the teammate hook saw `teams_env=1` and `C'"'"'` when it did not. A missing row is never inferred.\n' "$ALLOWED"
}

write_record() {
  local a status="complete: all four actors were driven and every row came from a captured line"
  for a in $ACTORS; do has_row "$SCRATCH/rows.txt" "$a" || MISSING="$MISSING $a"; done
  [ -n "$MISSING" ] && status="INCOMPLETE: no attributable row for ->$MISSING (rows absent, nothing inferred)"
  {
    echo "# Probe: PreToolUse identity fields for main, subagent and teammate ($DATE)"
    printf '\nRecord for esc-followups item 1 (docs/plans/2026-10-02-escalation-followups.md). Generated by `scripts/probe-hook-identity.sh`.\nScript: scripts/probe-hook-identity.sh @ %s\n' "$(git -C "$ROOT" rev-parse --short HEAD)"
    printf '\n## Method\n\n'; method_text
    printf '\n## Version\n\n`claude --version` reports `%s`.\n' "$VERSION"
    printf '\n## Status\n\n**self-reported**: produced by the script run by the operator in their own session. Run result: %s.\n' "$status"
    printf '\n## Rows\n\n```\n%s```\n\nOutcome: %s\n' "$ROWS" "$OUT"
    printf '\n## Cleanup\n\nAfter this body is written the script removes `%s`, then records two `Cleanup check:` lines: that directory is gone, and `git status --porcelain -- hooks .claude/settings.json` is empty.\n' "$SCRATCH"
    printf '\n## Appendix: raw capture.jsonl\n\n```\n'; cat "$CAP" 2>/dev/null; printf '```\n'
  } > "$SCRATCH/record.md"
  mkdir -p "$(dirname "$REC")"; cp "$SCRATCH/record.md" "$REC" || exit 2
}

yn() { if "$@"; then echo yes; else echo no; fi; }

finish_record() {
  local porc
  cleanup
  porc="$(git -C "$ROOT" status --porcelain -- hooks .claude/settings.json)" || porc="git status failed"
  {
    printf '\n## Cleanup checks\n\n'
    printf 'Cleanup check: scratch-removed %s\n' "$(yn test ! -e "$SCRATCH")"
    printf 'Cleanup check: repo-hook-surface-clean %s\n' "$(yn test -z "$porc")"
  } >> "$REC"
}

main() {
  trap cleanup EXIT
  command -v tmux >/dev/null && command -v claude >/dev/null && command -v jq >/dev/null || { echo "need tmux, claude and jq on PATH" >&2; exit 2; }
  setup
  echo "run 1: main + subagent ..." >&2; run_headless "$RAW/prompt-sub.txt" "" run1
  echo "run 2: main-teams + teammate ..." >&2; run_headless "$RAW/prompt-mate.txt" 1 run2
  have_marker 'echo probe-teammate' || { echo "no teammate marker; retrying in tmux ..." >&2; retry_teammate_tmux; }
  ROWS="$(classify_rows "$CAP")"; printf '%s\n' "$ROWS" > "$SCRATCH/rows.txt"
  OUT="$(outcome "$SCRATCH/rows.txt")"
  ROWS="$ROWS"$'\n'
  write_record
  finish_record
  echo "Outcome: $OUT"; echo "record: $REC"
  if [ -n "$MISSING" ]; then echo "INCOMPLETE:$MISSING" >&2; exit 3; fi
}
[ "${BASH_SOURCE[0]}" = "$0" ] && main "$@"
