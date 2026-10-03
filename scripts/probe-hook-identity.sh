#!/usr/bin/env bash
# Operator probe for esc-followups item 1: which identity fields does a PreToolUse hook see for main, subagent and teammate? Run: bash scripts/probe-hook-identity.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATE="$(date +%F)"
REC="${1:-$ROOT/docs/experiments/$DATE-probe-hook-identity.md}"
case $REC in /*) ;; *) REC="$PWD/$REC" ;; esac
SCRATCH="${PROBE_SCRATCH:-/tmp/hook-identity-probe}"
CAP="$SCRATCH/capture.jsonl"
RAW="$SCRATCH/raw"
TS="hook-identity-probe-$$"
ACTORS="main main-teams subagent teammate"
ALLOWED='Bash(echo probe-*)'
VERSION="" ; MISSING="" ; OUT="" ; ROWS="" ; TCHECK=none ; TLINE="" ; TMUX_RETRY="not-run (probe did not reach the retry decision)" ; TMUX_NOTE=""

cleanup() { tmux -L "$TS" kill-server 2>/dev/null; rm -rf "$SCRATCH"; }
tm() { tmux -L "$TS" "$@"; }

setup() {
  rm -rf "$SCRATCH"; mkdir -p "$SCRATCH/.claude" "$RAW"; cd "$SCRATCH" || exit 2
  cat > .claude/capture.sh <<EOH
#!/usr/bin/env bash
jq -c --arg env "\${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" --arg run "\$(cat $SCRATCH/run-id 2>/dev/null)" '{event:.hook_event_name, keys:(keys), agent_id:.agent_id, agent_type:.agent_type, session_id:.session_id, permission_mode:.permission_mode, cmd:.tool_input.command, name:.tool_input.name, transcript_path:.transcript_path, teams_env:\$env, run:\$run}' >> $CAP 2>/dev/null
exit 0
EOH
  chmod +x .claude/capture.sh
  printf '%s\n' 'Do exactly this and nothing else. 1) Run the Bash command `echo probe-main` yourself. 2) Dispatch ONE subagent with the Agent tool, no name, whose entire task is to run the Bash command `echo probe-subagent` and report. Never run `echo probe-subagent` yourself.' > "$RAW/prompt-sub.txt"
  printf '%s\n' 'Do exactly this and nothing else. 1) Run the Bash command `echo probe-main` yourself. 2) Create an agent team with one teammate named probe-mate. Its only task is to run the Bash command `echo probe-teammate`, then message the lead `done`. Never run `echo probe-teammate` yourself.' > "$RAW/prompt-mate.txt"
  VERSION="$(claude --version 2>&1 | head -1)"
}

setup_run() { # run-id teams-env(0|1): project settings beat user settings, so the env is set here; the teams_env column shows whether that held
  jq -n --arg c "$SCRATCH/.claude/capture.sh" --arg t "$2" '{env:{CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:$t},hooks:{
    PreToolUse:[{matcher:"Bash|Agent",hooks:[{type:"command",command:$c}]}],
    Stop:[{hooks:[{type:"command",command:$c}]}],
    SubagentStop:[{hooks:[{type:"command",command:$c}]}]}}' > "$SCRATCH/.claude/settings.json"
  printf '%s\n' "$1" > "$SCRATCH/run-id"
}

# pick <capture> <exact cmd> <1|2> -> every matching PreToolUse line from run1 (1) or run2* (2)
pick() {
  jq -c --arg c "$2" --arg r "run$3" 'select(.event=="PreToolUse" and .cmd==$c and ((.run // "")|startswith($r)))' "$1" 2>/dev/null
}

actor_line() { # capture actor -> first line for that actor's marker
  case $2 in
    main) pick "$1" 'echo probe-main' 1 ;;
    main-teams) pick "$1" 'echo probe-main' 2 ;;
    subagent) pick "$1" 'echo probe-subagent' 1 ;;
  esac | head -1
}

# a subagent/teammate marker is attributable only if no reference main transcript shows the lead running it
transcript_has() { # transcript cmd -> 0 found, 1 absent, 2 unreadable
  local rc
  [ -s "$1" ] || return 2 # BR-tx-unreadable
  jq -e --arg c "$2" 'select(any(..|objects; .type=="tool_use" and .name=="Bash" and .input.command? == $c))' "$1" >/dev/null 2>&1; rc=$?
  case $rc in 0) return 0 ;; 4) return 1 ;; *) return 2 ;; esac
}

attributable() { # capture actor cmd reference-actor
  local ref="$4" tp rc n=0
  case $2 in main|main-teams) return 0 ;; esac
  while read -r tp; do
    n=$((n + 1)); transcript_has "$tp" "$3"; rc=$?
    [ "$rc" = 1 ] || return 1
  done < <(case $ref in main) pick "$1" 'echo probe-main' 1 ;; *) pick "$1" 'echo probe-main' 2 ;; esac | jq -r '.transcript_path' | sort -u)
  [ "$n" -gt 0 ] # BR-tx-noref
}

clean() { tr -c 'A-Za-z0-9:._\n-' '_'; }
field() { jq -r "$1" <<<"$2" | clean | tr -d '\n'; } # jq-expr json -> one sanitized token

emit_row() { # capture actor line
  local id ty te se
  id="$(field 'if .agent_id==null then "absent" elif .agent_id=="" then "empty" else "present" end' "$3")"
  ty="$(field 'if .agent_type==null then "absent" elif .agent_type=="" then "empty" else .agent_type end' "$3")"
  te="$(field 'if (.teams_env // "")=="" then "unset" else .teams_env end' "$3")"
  se="$(jq -r --argjson l "$3" 'select((.event=="Stop" or .event=="SubagentStop") and .session_id==$l.session_id and .agent_id==$l.agent_id) | .event' "$1" | head -1 | clean | tr -d '\n')"
  printf 'Identity row: %s agent_id=%s agent_type=%s teams_env=%s stop_event=%s %s observed\n' "$2" "$id" "$ty" "$te" "${se:-none}" "$DATE"
  printf 'Keys row: %s %s\n' "$2" "$(jq -r '.keys | sort[]' <<<"$3" | clean | paste -sd' ')"
}

# a "teammate" that is a plain subagent: lead's session, an agent_id, a SubagentStop in that session, and only subagent-control keys
looks_like_subagent() { # capture teammate-line main-teams-line
  local aid sid msid sk
  aid="$(jq -r '.agent_id // ""' <<<"$2")"; sid="$(jq -r '.session_id' <<<"$2")"; msid="$(jq -r '.session_id // empty' <<<"${3:-null}")"
  sk="$(pick "$1" 'echo probe-subagent' 1 | head -1 | jq -c '.keys')"
  [ -n "$aid" ] && [ "$sid" = "$msid" ] || return 1
  jq -e --argjson l "$2" 'select(.event=="SubagentStop" and .agent_id==$l.agent_id and .session_id==$l.session_id)' "$1" >/dev/null 2>&1 || return 1
  jq -e --argjson s "${sk:-[]}" '(.keys - $s) | length == 0' <<<"$2" >/dev/null 2>&1
}

teammate_check() { # capture teammate-line main-teams-line -> genuine | teams-off | subagent-shaped
  [ "$(jq -r '.teams_env // ""' <<<"$2")" = 1 ] || { echo teams-off; return; } # BR-teams-off
  if looks_like_subagent "$1" "$2" "$3"; then echo subagent-shaped; return; fi # BR-subagent-shaped
  echo genuine
}

teammate_choose() { # capture -> sets TCHECK/TLINE: the first genuine candidate, else the first candidate's check
  local l m c
  TCHECK=none; TLINE=""
  while IFS= read -r l; do
    m="$(pick "$1" 'echo probe-main' 2 | jq -c --arg r "$(jq -r '.run // ""' <<<"$l")" 'select(.run==$r)' | head -1)"
    c="$(teammate_check "$1" "$l" "$m")"
    if [ "$TCHECK" = none ]; then TCHECK=$c; TLINE=$l; fi
    if [ "$c" = genuine ]; then TCHECK=$c; TLINE=$l; break; fi
  done < <(pick "$1" 'echo probe-teammate' 2)
}

classify_rows() { # capture.jsonl -> Identity/Keys rows for every attributable actor, plus the teammate genuineness check
  local a l cmd ref
  for a in main main-teams subagent; do
    l="$(actor_line "$1" "$a")"; [ -n "$l" ] || continue
    case $a in subagent) cmd='echo probe-subagent'; ref=main ;; *) cmd=""; ref="" ;; esac
    attributable "$1" "$a" "$cmd" "$ref" || continue
    emit_row "$1" "$a" "$l"
  done
  teammate_choose "$1"
  printf 'Teammate check: %s\n' "$TCHECK"
  [ "$TCHECK" = genuine ] || return 0
  attributable "$1" teammate 'echo probe-teammate' main-teams || return 0
  emit_row "$1" teammate "$TLINE"
}

rf() { grep -m1 "^Identity row: $2 " "$1" | tr ' ' '\n' | sed -n "s/^$3=//p" | head -1; } # rows-file actor field: first key=value token
has_row() { grep -q "^Identity row: $2 " "$1"; }

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

outcome() { # rows-file -> exactly one of A B C C' D U X
  local f=$1
  has_row "$f" main && has_row "$f" main-teams || { echo U; return; }
  has_row "$f" subagent || { echo U; return; } # BR-sub-missing
  [ "$(rf "$f" main agent_id)" = absent ] || { echo X; return; }
  [ "$(rf "$f" main-teams agent_id)" = absent ] || { echo X; return; } # BR-maint-aid
  [ "$(rf "$f" subagent agent_id)" = present ] || { echo X; return; } # BR-sub-aid
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

run_headless() { # prompt-file run-id -> one claude -p run in the scratch dir
  ( cd "$SCRATCH" && timeout 180 claude -p "$(cat "$1")" --allowedTools "$ALLOWED" Agent >> "$RAW/$2.txt" 2>&1 )
}

pane_state() { # pane-text -> ready | trust | wait
  if grep -qi trust <<<"$1"; then echo trust
  elif grep -q '^❯' <<<"$1"; then echo ready
  else echo wait; fi
}

teammate_done() { # capture [run-prefix]: teammate marker's PreToolUse followed by a Stop/SubagentStop with the same session_id and agent_id
  jq -se --arg c 'echo probe-teammate' --arg r "${2:-}" '. as $a | any(range(0; length); . as $i | $a[$i] as $m | $m.event=="PreToolUse" and $m.cmd==$c and ((($m.run // "")|startswith($r))) and any($a[$i+1:][]; (.event=="Stop" or .event=="SubagentStop") and .session_id==$m.session_id and .agent_id==$m.agent_id))' "$1" >/dev/null 2>&1
}

retry_teammate_tmux() {
  local i
  tm new-session -d -s mate -x 200 -y 60 -c "$SCRATCH" "claude --allowedTools '$ALLOWED' Agent"
  for ((i = 0; i < 30; i++)); do
    case "$(pane_state "$(tm capture-pane -p -t mate 2>/dev/null)")" in
      ready) break ;;
      trust) if [ -z "$TMUX_NOTE" ]; then tm send-keys -t mate Enter; TMUX_NOTE="workspace-trust prompt accepted for $SCRATCH"; fi ;;
    esac
    sleep 1
  done
  sleep 2
  tm load-buffer -b mate "$RAW/prompt-mate.txt"; tm paste-buffer -p -b mate -t mate; sleep 1
  tm send-keys -t mate Enter
  for ((i = 0; i < 180; i++)); do teammate_done "$CAP" run2-tmux && break; sleep 1; done
  tm capture-pane -p -S - -t mate > "$RAW/teammate-tmux.txt" 2>/dev/null
  tm kill-session -t mate
}

method_text() {
  printf 'The script builds a scratch dir outside the repo. Its `.claude/settings.json` registers one capture hook on `PreToolUse` (matcher `Bash|Agent`), `Stop` and `SubagentStop`, and sets `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` per run (project settings beat user settings; the `teams_env` column reports what the hook actually saw and is never used to pick a row). The hook appends one JSON line per event to `capture.jsonl`: `event`, sorted payload `keys`, `agent_id`, `agent_type`, `session_id`, `permission_mode`, `transcript_path`, the command `cmd`, the Agent-tool `name`, `teams_env`, and `run` (`run1`, `run2` or `run2-tmux`, read from a file the script rewrites before each run). It prints nothing and always exits 0. Run 1 is `claude -p` with `--allowedTools '"'"'%s'"'"' Agent` and teams off: the main session runs `echo probe-main` and dispatches one unnamed subagent that runs `echo probe-subagent`. Run 2 is the same with teams on and a request to create an agent team with one teammate `probe-mate` that runs `echo probe-teammate`; its main marker is the `main-teams` control. Rows are picked by run, not by `teams_env`: `main` and `subagent` from `run1`, `main-teams` and `teammate` from `run2*`. A row is written only when a PreToolUse(Bash) line has a command exactly equal to the marker. For subagent and teammate the row is also withheld unless every reference main transcript (`main` for subagent, `main-teams` for teammate) is readable and holds no Bash `tool_use` of that marker, because otherwise the lead may have run it itself. `stop_event` is the `Stop`/`SubagentStop` line with the same `session_id` and `agent_id`, else `none`. A teammate row is written only when `Teammate check:` is `genuine`: `teams-off` when the teammate hook did not see `teams_env=1`; `subagent-shaped` when it has an `agent_id`, the lead'"'"'s `session_id`, a `SubagentStop` with that `agent_id` and `session_id`, and only keys the subagent control also has; `genuine` otherwise. Honest limit: a real in-process teammate that carries an `agent_id` and a lead-session `SubagentStop` cannot be told from a subagent, so it is classified `subagent-shaped` and the outcome is D; that is conservative because both gates already deny any non-empty `agent_id`. Whether a teammate can be spawned headless at all is not known; the script reports what the check saw and infers nothing. If run 2 yields no `genuine` teammate the script retries once in a detached tmux interactive session (run `run2-tmux`), accepting a workspace-trust prompt once if one appears, and waits up to 180 s for the teammate marker followed by a stop line. `Outcome:` is the pure `outcome()` function over the rows: `U` if the main, main-teams or subagent row is missing (the run is incomplete, nothing is inferred); `X` if a control row that exists disagrees (main or main-teams `agent_id` not absent, subagent not present); `D` with no teammate row; `A` if the teammate `agent_id` is present; `B` if it is absent/empty but `agent_type` differs from every main row or a payload key appears that no main row has; else `C`. All payload-derived values are sanitized to `[A-Za-z0-9:._-]` before they are written.\n' "$ALLOWED"
}

write_record() {
  local a tc status="complete: all four actors were driven and every row came from a captured line"
  for a in $ACTORS; do has_row "$SCRATCH/rows.txt" "$a" || MISSING="$MISSING $a"; done
  [ -n "$MISSING" ] && status="INCOMPLETE: no attributable row for ->$MISSING (rows absent, nothing inferred)"
  tc="$(sed -n 's/^Teammate check: //p' <<<"$ROWS" | head -1)"
  {
    echo "# Probe: PreToolUse identity fields for main, subagent and teammate ($DATE)"
    printf '\nRecord for esc-followups item 1 (docs/plans/2026-10-02-escalation-followups.md). Generated by `scripts/probe-hook-identity.sh`.\nScript: scripts/probe-hook-identity.sh @ %s\n' "$(git -C "$ROOT" rev-parse --short HEAD)"
    printf '\n## Method\n\n'; method_text
    printf '\n## Version\n\n`claude --version` reports `%s`.\n' "$VERSION"
    printf '\n## Status\n\n**self-reported**: produced by the script run by the operator in their own session. Run result: %s. Teammate check: %s.\n' "$status" "${tc:-none}"
    printf '\nTmux retry: %s\n' "$TMUX_RETRY"
    [ -n "$TMUX_NOTE" ] && printf 'Tmux note: %s\n' "$TMUX_NOTE"
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
  echo "run 1: main + subagent ..." >&2; setup_run run1 0; run_headless "$RAW/prompt-sub.txt" run1
  echo "run 2: main-teams + teammate ..." >&2; setup_run run2 1; run_headless "$RAW/prompt-mate.txt" run2
  teammate_choose "$CAP"
  if [ "$TCHECK" = genuine ]; then
    TMUX_RETRY="not-run (genuine teammate captured headless)"
  else
    TMUX_RETRY="ran ($TCHECK)"; echo "no genuine teammate ($TCHECK); retrying in tmux ..." >&2
    setup_run run2-tmux 1; retry_teammate_tmux
  fi
  ROWS="$(classify_rows "$CAP")"; printf '%s\n' "$ROWS" > "$SCRATCH/rows.txt"
  OUT="$(outcome "$SCRATCH/rows.txt")"
  ROWS="$ROWS"$'\n'
  write_record
  finish_record
  echo "Outcome: $OUT"; echo "record: $REC"
  if [ -n "$MISSING" ]; then echo "INCOMPLETE:$MISSING" >&2; exit 3; fi
}
[ "${BASH_SOURCE[0]}" = "$0" ] && main "$@"
