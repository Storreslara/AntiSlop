#!/usr/bin/env bash
# Operator probe for esc-chat-1: does a PreToolUse "ask" on a Bash heredoc show the full command, per mode? Run: bash scripts/probe-bash-ask.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REC="${1:-$ROOT/docs/experiments/2026-10-01-probe-bash-ask.md}"
SCRATCH=/tmp/bash-ask-probe
RAW="$SCRATCH/raw"
TS="bash-ask-probe-$$"
DATE="$(date +%F)"
MODES="default plan acceptEdits auto dontAsk bypassPermissions"
ROWS="" ; MISSING="" ; VERSION="" ; HL_CLASSIFIER="none (no denial classified)"

cleanup() { tmux -L "$TS" kill-server 2>/dev/null; rm -rf "$SCRATCH"; }
trap cleanup EXIT
tm() { tmux -L "$TS" "$@"; }
pane() { tm capture-pane -p -S - -t "$1" 2>/dev/null; }

setup() {
  rm -rf "$SCRATCH"; mkdir -p "$SCRATCH/.claude" "$RAW"; cd "$SCRATCH" || exit 2
  cat > .claude/ask.sh <<'EOS'
#!/usr/bin/env bash
cat >/dev/null
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"probe: approve only if the full heredoc below is visible"}}\n'
EOS
  chmod +x .claude/ask.sh
  printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"%s/.claude/ask.sh"}]}]}}\n' "$PWD" > .claude/settings.json
  printf '%s\n' 'Run exactly this Bash command and nothing else:' "cat > out.txt <<'EOF'" \
    line-1 line-2 line-3 line-4 line-5 line-6-END EOF > "$RAW/request.txt"
  VERSION="$(claude --version 2>&1 | head -1)"
}

# poll the pane until a pattern appears; returns 1 on timeout
wait_for() { # session grep-ere timeout-seconds
  local i; for ((i = 0; i < $3; i++)); do
    pane "$1" | grep -qE "$2" && return 0; sleep 1
  done; return 1
}

# text of the last permission dialog only (never the echoed request or tool-call log)
dialog() { pane "$1" | awk '/^ Bash command$/ {buf=""; on=1} on {buf = buf $0 "\n"} /Do you want to proceed\?/ {on=0; last=buf} END {printf "%s", last}'; }

row() { ROWS="$ROWS$1"$'\n'; }
miss() { MISSING="$MISSING $1"; echo "AMBIGUOUS/UNDRIVEN: $1" >&2; }
# plan is informational by policy (Amendment A1): never a miss, never gated
unseen() { # mode reason
  if [ "$1" = plan ]; then row "Info row: plan not-driven $DATE informational"; else miss "$1 $2"; fi
}

classify() { # session -> prints verdict or nothing
  local i; for ((i = 0; i < 90; i++)); do
    if pane "$1" | grep -q 'Do you want to proceed?'; then echo prompt-rendered; return; fi
    if [ -e "$SCRATCH/out.txt" ]; then echo auto-approved; return; fi
    if pane "$1" | sed '1,/line-6-END/d' | grep -qiE 'denied|blocked|not allowed|not permitted'; then echo denied; return; fi
    sleep 1
  done
}

display_and_decline() { # mode session
  local m=$1 s=$2 d vis=yes l
  d="$(dialog "$s")"
  for l in line-1 line-2 line-3 line-4 line-5 line-6-END EOF; do grep -qF "$l" <<<"$d" || vis=no; done
  row "Display row: $m full-heredoc-visible $vis $DATE observed"
  tm send-keys -t "$s" 2   # "2. No" in the numbered permission menu
  if ! wait_for "$s" 'Interrupted|What should Claude do instead' 20; then miss "$m decline (screen did not confirm the decline)"; return; fi
  sleep 2
  if [ -e "$SCRATCH/out.txt" ]; then row "Decline row: $m file-absent no $DATE observed"
  else row "Decline row: $m file-absent yes $DATE observed"; fi
}

probe_mode() {
  local m=$1 s="p-$1" v
  rm -f "$SCRATCH/out.txt"
  tm new-session -d -s "$s" -x 200 -y 60 -c "$SCRATCH" "claude --permission-mode $m"
  if ! wait_for "$s" '^❯' 30; then unseen "$m" readiness; pane "$s" > "$RAW/$m.txt"; tm kill-session -t "$s"; return; fi
  sleep 2
  tm load-buffer -b "$s" "$RAW/request.txt"; tm paste-buffer -p -b "$s" -t "$s"; sleep 1
  tm send-keys -t "$s" Enter
  v="$(classify "$s")"
  if [ -z "$v" ]; then unseen "$m" "verdict (no prompt, file or denial within 90s)"
  elif [ "$m" = plan ]; then row "Info row: plan $v $DATE informational observed"
  else
    row "Probe row: $m $v $DATE observed"
    [ "$v" = prompt-rendered ] && display_and_decline "$m" "$s"
  fi
  pane "$s" > "$RAW/$m.txt"
  tm kill-session -t "$s"
}

probe_headless() {
  local out v
  rm -f "$SCRATCH/out.txt"
  out="$(cd "$SCRATCH" && timeout 120 claude -p "run: printf x > out.txt" --permission-mode default --output-format json 2>"$RAW/headless.err")" ; echo "rc=$?" >> "$RAW/headless.txt"
  printf '%s\n' "$out" >> "$RAW/headless.txt"
  if [ -e "$SCRATCH/out.txt" ]; then v=auto-approved
  elif jq -e '(.permission_denials // []) | map(select(.tool_name=="Bash")) | length > 0' <<<"$out" >/dev/null 2>&1; then v=denied; HL_CLASSIFIER='the JSON `permission_denials` list naming a Bash tool'
  elif ! jq -e 'has("permission_denials")' <<<"$out" >/dev/null 2>&1 && grep -qiE '(permission|approval).{0,40}(denied|required|was not granted)|requires? (your )?approval' <<<"$(jq -r '.result // empty' <<<"$out" 2>/dev/null)"; then v=denied; HL_CLASSIFIER='the anchored phrase regex on the JSON `result` text (the JSON has no `permission_denials` field)'
  else miss "headless-p verdict (no file, no structured denial evidence)"; return; fi
  row "Probe row: headless-p $v $DATE observed"
}

gate() { # prints GREEN or RED
  local f=$1 m
  for m in default acceptEdits auto; do
    grep -qE "^Probe row: $m prompt-rendered .* observed$" "$f" && grep -qE "^Display row: $m full-heredoc-visible yes .* observed$" "$f" && grep -qE "^Decline row: $m file-absent yes .* observed$" "$f" || { echo RED; return; }
  done
  grep -qxF 'Cleanup check: scratch-removed yes' "$f" && grep -qxF 'Cleanup check: repo-hooks-probe-free yes' "$f" && grep -qxF 'Cleanup check: repo-hook-surface-clean yes' "$f" || { echo RED; return; }
  echo GREEN
}

write_record() {
  local tmp="$SCRATCH/record.md" status="complete: every non-informational mode was driven and classified from captured panes" m
  [ -n "$MISSING" ] && status="INCOMPLETE: not driven or ambiguous ->$MISSING (rows absent, nothing inferred)"
  {
    echo "# Probe: Bash \`ask\` heredoc display across permission modes ($DATE)"
    printf '\nRecord for spec esc-chat-1 (docs/plans/2026-10-01-in-session-escalation-decision.md). Generated by `scripts/probe-bash-ask.sh`.\nScript: scripts/probe-bash-ask.sh @ %s\n' "$(git -C "$ROOT" rev-parse --short HEAD)"
    printf '\n## Method\n\nThe script builds a scratch dir outside the repo with a PreToolUse hook that always returns `ask` for Bash. For each mode it starts `claude --permission-mode <mode>` in a detached tmux session, pastes a 7-line heredoc request, and polls the pane. A prompt is `prompt-rendered` when "Do you want to proceed?" appears; `auto-approved` when `out.txt` appears with no prompt; `denied` when denial text appears. Visibility is checked only inside the last permission dialog, with no expansion keystroke sent: `line-1`..`line-6-END` and `EOF` must all be present. The prompt is declined with key `2` (the "No" entry of the numbered menu), then `out.txt` is checked absent. The `plan` mode is attempted but informational by policy (Amendment A1: plan is read-only, so there is no write approval for a human to make); it is written as an `Info row`, never gates, and its absence is not a miss. Headless is `claude -p "run: printf x > out.txt" --permission-mode default --output-format json`; `denied` is classified only when `out.txt` is absent and the evidence is %s. A mode that cannot be classified from the captured screen gets no row.\n' "$HL_CLASSIFIER"
    printf '\n## Version\n\n`claude --version` reports `%s`.\n' "$VERSION"
    printf '\n## Status\n\n**self-reported**: this record was produced by the script run by the operator in their own session; rows are `observed` only where derived from the captured pane text in the appendix. Run result: %s.\n' "$status"
    printf '\n## Rows\n\n```\n%s```\n' "$ROWS"
    printf '\n## Cleanup\n\nAfter this record body is written the script runs its cleanup, then checks exactly three things, recorded as `Cleanup check:` lines before the ship gate: `%s` is gone, `hooks/hooks.json` contains no `probe`, and `git status --porcelain -- hooks .claude/settings.json` is empty. Any `no` forces the gate RED.\n' "$SCRATCH"
    printf '\n## Appendix: raw captured panes\n'
    for m in $MODES headless; do
      [ -f "$RAW/$m.txt" ] && { printf '\n### %s\n\n```\n' "$m"; cat "$RAW/$m.txt"; printf '```\n'; }
    done
  } > "$tmp"
  mkdir -p "$(dirname "$REC")"; cp "$tmp" "$REC"
}

yn() { if "$@"; then echo yes; else echo no; fi; }

finish_record() { # after cleanup: check, append the checks, then the gate
  local porc
  cleanup
  porc="$(git -C "$ROOT" status --porcelain -- hooks .claude/settings.json)"
  {
    printf '\nCleanup check: scratch-removed %s\n' "$(yn test ! -e "$SCRATCH")"
    printf 'Cleanup check: repo-hooks-probe-free %s\n' "$(yn bash -c '! grep -qi probe "$1"' _ "$ROOT/hooks/hooks.json")"
    printf 'Cleanup check: repo-hook-surface-clean %s\n' "$(yn test -z "$porc")"
  } >> "$REC"
  printf '\nShip gate: %s\n' "$(gate "$REC")" >> "$REC"
}

main() {
  command -v tmux >/dev/null && command -v claude >/dev/null || { echo "need tmux and claude on PATH" >&2; exit 2; }
  setup
  local m; for m in $MODES; do echo "probing $m ..." >&2; probe_mode "$m"; done
  echo "probing headless-p ..." >&2; probe_headless
  write_record
  finish_record
  tail -n 1 "$REC"; echo "record: $REC"
  if [ -n "$MISSING" ]; then echo "INCOMPLETE:$MISSING" >&2; exit 3; fi
}
main
