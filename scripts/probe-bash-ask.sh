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
PLANS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plans"

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
  VERSION="$(claude_ver)"
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
claude_ver() { local v; v="$(claude --version 2>/dev/null | head -1)"; printf '%s\n' "${v:-unreadable}"; }
mode_version() { claude_ver > "$RAW/$1.version"; }
ver_of() { cat "$RAW/$1.version" 2>/dev/null || echo unreadable; }
plans_ls() { { [ ! -e "$PLANS" ] || ls -Aq "$PLANS"; } > "$RAW/plans.$1" 2>/dev/null || rm -f "$RAW/plans.$1"; }
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
  if [ -n "$d" ]; then printf '%s\n' "$d"; fi > "$RAW/$m.dialog"   # the exact text Probe/Display are graded on, saved before the decline
  for l in line-1 line-2 line-3 line-4 line-5 line-6-END; do grep -qF "$l" <<<"$d" || vis=no; done
  sed '1,/line-6-END/d' <<<"$d" | grep -qE '^[^[:alnum:]]*EOF[^[:alnum:]]*$' || vis=no   # closing EOF as its own line, after line-6-END
  row "Display row: $m full-heredoc-visible $vis $DATE observed"
  tm send-keys -t "$s" 2   # "2. No" in the numbered permission menu
  if ! wait_for "$s" 'Interrupted|What should Claude do instead' 20; then miss "$m decline (screen did not confirm the decline)"; return; fi
  sleep 2
  { if [ -e "$SCRATCH/out.txt" ]; then echo 'out.txt: present'; else echo 'out.txt: absent'; fi; echo 'ls -Aq scratch dir:'; ls -Aq "$SCRATCH"; } > "$RAW/$m.decline" 2>/dev/null   # the decline evidence; the row is derived from this saved text
  if grep -qx 'out.txt: absent' "$RAW/$m.decline"; then row "Decline row: $m file-absent yes $DATE observed"
  else row "Decline row: $m file-absent no $DATE observed"; fi
}

probe_mode() {
  local m=$1 s="p-$1" v
  rm -f "$SCRATCH/out.txt"; mode_version "$m"
  tm new-session -d -s "$s" -x 200 -y 60 -c "$SCRATCH" "claude --permission-mode $m"
  if ! wait_for "$s" '^❯' 30; then unseen "$m" readiness; pane "$s" > "$RAW/$m.txt"; tm kill-session -t "$s"; return; fi
  sleep 2
  tm load-buffer -b "$s" "$RAW/request.txt"; tm paste-buffer -p -b "$s" -t "$s"; sleep 1
  tm send-keys -t "$s" Enter
  v="$(classify "$s")"
  if [ -z "$v" ]; then unseen "$m" "verdict (no prompt, file or denial within 90s)"
  elif [ "$m" = plan ]; then row "Info row: plan $v $DATE observed informational"
  else
    row "Probe row: $m $v $DATE observed"
    [ "$v" = prompt-rendered ] && display_and_decline "$m" "$s"
  fi
  pane "$s" > "$RAW/$m.txt"
  tm kill-session -t "$s"
}

probe_headless() {
  local out v
  rm -f "$SCRATCH/out.txt"; mode_version headless
  out="$(cd "$SCRATCH" && timeout 120 claude -p "run: printf x > out.txt" --permission-mode default --output-format json 2>"$RAW/headless.err")" ; echo "rc=$?" >> "$RAW/headless.txt"
  out="$(jq -c 'with_entries(select(.key == "permission_denials" or .key == "result"))' <<<"$out" 2>/dev/null)" || out="(output was not a JSON object; not saved)"   # keep only what the classifier reads
  printf '%s\n' "$out" >> "$RAW/headless.txt"
  if [ -e "$SCRATCH/out.txt" ]; then v=auto-approved
  elif jq -e '(.permission_denials // []) | map(select(.tool_name=="Bash")) | length > 0' <<<"$out" >/dev/null 2>&1; then v=denied; HL_CLASSIFIER='the JSON `permission_denials` list naming a Bash tool'
  elif ! jq -e 'has("permission_denials")' <<<"$out" >/dev/null 2>&1 && grep -qiE '(permission|approval).{0,40}(denied|required|was not granted)|requires? (your )?approval' <<<"$(jq -r '.result // empty' <<<"$out" 2>/dev/null)"; then v=denied; HL_CLASSIFIER='the anchored phrase regex on the JSON `result` text (the JSON has no `permission_denials` field)'
  else miss "headless-p verdict (no file, no structured denial evidence)"; return; fi
  row "Probe row: headless-p $v $DATE observed"
}

gate() { # prints GREEN or RED
  local f=$1 m n b c d e p
  b="$(sed '/^## Appendix/,$d' "$f")"   # rows: everything before the raw-pane appendix
  if grep -qx '## Cleanup checks' "$f"; then c="$(awk '/^## Cleanup checks$/{blk=""; next} {blk=blk $0 "\n"} END{printf "%s", blk}' "$f")"   # block after the LAST marker
    ! grep -q '^```' <<<"$c" || { echo RED; return; }   # a fence after it means the marker sits inside the appendix, not a real block
  else c="$b"; fi   # no marker: only the pre-appendix text counts, so appendix lines never grade
  # want's own block of one kind: the leading run of blocks after the first Appendix heading, each skipped by its declared line count so its text is never read as structure
  p='
      !a { a = /^## Appendix/; next }
      st == 0 && /^$/ { next }
      st == 0 && /^### (dialog|decline): [^ ]+ [0-9]+ lines/ { kd = $2; md = $3; n = $4 + 0; st = 1; next }
      st == 0 { exit }
      st == 1 { if ($0 != "```") { bad = 1; exit } st = n ? 2 : 3; k = 0; next }
      st == 2 { if (kd == kind && md == want) buf = buf $0 "\n"; if (++k == n) st = 3; next }
      st == 3 { if ($0 != "```") { bad = 1; exit } cnt[kd md]++; st = 0; next }
      END { if (bad || st != 0 || cnt[kind want] != 1) exit 1; printf "%s", buf }'
  for m in default acceptEdits auto; do
    grep -qE "^Probe row: $m prompt-rendered .* observed$" <<<"$b" && grep -qE "^Display row: $m full-heredoc-visible yes .* observed$" <<<"$b" && grep -qE "^Decline row: $m file-absent yes .* observed$" <<<"$b" || { echo RED; return; }
    d="$(awk -v want="$m" -v kind=dialog: "$p" "$f")" || { echo RED; return; }
    for n in 'Do you want to proceed?' line-1 line-2 line-3 line-4 line-5 line-6-END; do grep -qF -- "$n" <<<"$d" || { echo RED; return; }; done
    sed '1,/line-6-END/d' <<<"$d" | grep -qE '^[^[:alnum:]]*EOF[^[:alnum:]]*$' || { echo RED; return; }   # closing EOF as its own line, after line-6-END
    e="$(awk -v want="$m" -v kind=decline: "$p" "$f")" || { echo RED; return; }
    grep -qx 'out.txt: absent' <<<"$e" && ! grep -qxE 'out\.txt(: present)?' <<<"$e" || { echo RED; return; }   # the check says absent; no line says present, no listing shows out.txt
  done
  for n in scratch-removed repo-hooks-probe-free repo-hook-surface-clean; do   # each check exactly once in the block, and yes
    [ "$(grep -cE "^Cleanup check: $n " <<<"$c")" = 1 ] && grep -qxF "Cleanup check: $n yes" <<<"$c" || { echo RED; return; }
  done
  echo GREEN
}

write_record() {
  local tmp="$SCRATCH/record.md" status="complete: every non-informational mode was driven and classified (headless-p from its JSON output)" vs
  [ -n "$MISSING" ] && status="INCOMPLETE: not driven or ambiguous ->$MISSING (rows absent, nothing inferred)"
  {
    echo "# Probe: Bash \`ask\` heredoc display across permission modes ($DATE)"
    printf '\nRecord for spec esc-chat-1 (docs/plans/2026-10-01-in-session-escalation-decision.md). Generated by `scripts/probe-bash-ask.sh`.\nScript: scripts/probe-bash-ask.sh @ %s\n' "$(git -C "$ROOT" rev-parse --short HEAD)"
    printf '\n## Method\n\nThe script builds a scratch dir outside the repo with a PreToolUse hook that always returns `ask` for Bash. For each mode it starts `claude --permission-mode <mode>` in a detached tmux session, pastes a 7-line heredoc request, and polls the pane. A prompt is `prompt-rendered` when "Do you want to proceed?" appears; `auto-approved` when `out.txt` appears with no prompt; `denied` when denial text appears. Visibility is checked only inside the last permission dialog, with no expansion keystroke sent: `line-1`..`line-6-END` must all be present, followed by a closing `EOF` on its own line. The prompt is declined with key `2` (the "No" entry of the numbered menu), then `out.txt` is checked absent. The `plan` mode is attempted but informational by policy (Amendment A1: plan is read-only, so there is no write approval for a human to make); it is written as an `Info row`, never gates, and its absence is not a miss. The `plan` run can also write a plan file under `~/.claude/plans/` (`$CLAUDE_CONFIG_DIR/plans/` when that is set), outside the scratch dir, and no Cleanup check covers it: the script lists that directory (`ls -Aq`) before and after each mode run and writes each new file name as a `Side effect:` line under Side effects, or says the listing was not possible; it never infers one. Headless is `claude -p "run: printf x > out.txt" --permission-mode default --output-format json`; `denied` is classified only when `out.txt` is absent and the evidence is %s. A mode that cannot be classified from the captured screen gets no row.\n' "$HL_CLASSIFIER"
    printf '\nEvidence per row. For each mode with a `prompt-rendered` Probe row (plan never has one: it gets only an `Info row` and is never declined), the permission dialog text (from the ` Bash command` header to "Do you want to proceed?") is captured before the decline key is sent and saved as that mode'"'"'s dialog block at the top of the appendix (dialog blocks first, then decline blocks), headed `### dialog: <mode> <N> lines, claude <version>`. The Display row is graded from exactly that text, and the ship gate re-checks default, acceptEdits and auto each against its own block (the marker, `line-1`..`line-6-END`, a closing `EOF` line), so those Probe and Display rows can be re-graded from this record. A Probe verdict other than `prompt-rendered` comes from the live pane (denial text) or the filesystem (`auto-approved`), and only the post-run pane is saved for it. The Decline row is the filesystem check of `out.txt` after the decline, not pane text: its output (`out.txt: absent` or `out.txt: present`, then the `ls -Aq` listing of the scratch dir) is saved as that mode'"'"'s decline block, headed `### decline: <mode> <N> lines`, the Decline row is derived from that saved text, and the ship gate re-checks default, acceptEdits and auto each against its own decline block (an `out.txt: absent` line, no `out.txt: present` line, no `out.txt` in the listing); the post-decline pane in the appendix is context only. Headless is graded from its JSON output, filtered with jq to its `permission_denials` and `result` fields (the only fields the classifier reads) and saved in that form under its own appendix heading.\n'
    printf '\n## Version\n\n`claude --version` reports `%s` at setup. Each mode'"'"'s own reading, taken at that mode'"'"'s start, is on its appendix block headers.\n' "$VERSION"
    vs="$(for m in $MODES headless; do printf '%s=%s\n' "$m" "$(ver_of "$m")"; done)"
    if [ "$( { echo "$VERSION"; sed 's/^[^=]*=//' <<<"$vs"; } | sort -u | wc -l)" -gt 1 ]; then
      printf 'Version note: the per-mode readings differ from each other or from the setup reading above (%s); each was taken at its mode'"'"'s start.\n' "$(paste -sd '|' <<<"$vs" | sed 's/|/, /g')"
    fi
    printf '\n## Status\n\n**self-reported**: this record was produced by the script run by the operator in their own session; `observed` means the script classified the row during this run, from the evidence named under Method. Run result: %s.\n' "$status"
    printf '\n## Rows\n\n```\n%s```\n' "$ROWS"
    printf '\n## Cleanup\n\nAfter this record body is written the script runs its cleanup, then checks exactly three things, recorded as `Cleanup check:` lines before the ship gate: `%s` is gone, `hooks/hooks.json` exists, is readable, and contains no `probe`, and `git status --porcelain -- hooks .claude/settings.json` is empty. Any `no` forces the gate RED.\n' "$SCRATCH"
    printf '\n## Side effects\n\n'; side_effect
    write_appendix
  } > "$tmp"
  mkdir -p "$(dirname "$REC")"; cp "$tmp" "$REC" || exit 2
}

write_appendix() { # dialog blocks first (length-prefixed, read by gate()), then the raw panes
  local m
  printf '\n## Appendix: dialog blocks and raw captured panes\n'
  for m in $MODES; do
    [ -f "$RAW/$m.dialog" ] && { printf '\n### dialog: %s %s lines, claude %s\n```\n' "$m" "$(( $(wc -l < "$RAW/$m.dialog") ))" "$(ver_of "$m")"; cat "$RAW/$m.dialog"; printf '```\n'; }
  done
  for m in $MODES; do
    [ -f "$RAW/$m.decline" ] && { printf '\n### decline: %s %s lines\n```\n' "$m" "$(( $(wc -l < "$RAW/$m.decline") ))"; cat "$RAW/$m.decline"; printf '```\n'; }
  done
  for m in $MODES headless; do
    [ -f "$RAW/$m.txt" ] && { printf '\n### %s (claude %s)\n\n```\n' "$m" "$(ver_of "$m")"; cat "$RAW/$m.txt"; printf '```\n'; }
  done
}

side_effect() { # Side effect: lines from the plans-dir listings taken before and after each mode run
  local m f new out="" p="${PLANS/#$HOME/\~}"
  for m in $MODES; do
    if [ ! -f "$RAW/plans.$m.before" ] || [ ! -f "$RAW/plans.$m.after" ]; then out="${out}Side effect: $m run: not detectable ($p could not be listed before and after it)"$'\n'; continue; fi
    new="$(comm -13 <(sort "$RAW/plans.$m.before") <(sort "$RAW/plans.$m.after"))"
    [ -z "$new" ] || while IFS= read -r f; do out="${out}Side effect: $m run: new file $p/$f"$'\n'; done <<<"$new"
  done
  if [ -n "$out" ]; then printf '%s' "$out"; else echo "Side effect: none: no new file under $p during any mode run"; fi
}

yn() { if "$@"; then echo yes; else echo no; fi; }

finish_record() { # after cleanup: check, append the checks, then the gate
  local porc
  cleanup
  porc="$(git -C "$ROOT" status --porcelain -- hooks .claude/settings.json)" || porc="git status failed"
  {
    printf '\n## Cleanup checks\n\n'
    printf 'Cleanup check: scratch-removed %s\n' "$(yn test ! -e "$SCRATCH")"
    printf 'Cleanup check: repo-hooks-probe-free %s\n' "$(yn bash -c 'test -f "$1" && { grep -qi probe "$1"; test $? -eq 1; }' _ "$ROOT/hooks/hooks.json")"
    printf 'Cleanup check: repo-hook-surface-clean %s\n' "$(yn test -z "$porc")"
  } >> "$REC"
  printf '\nShip gate: %s\n' "$(gate "$REC")" >> "$REC"
}

main() {
  command -v tmux >/dev/null && command -v claude >/dev/null && command -v jq >/dev/null || { echo "need tmux, claude and jq on PATH" >&2; exit 2; }
  setup
  local m; for m in $MODES; do echo "probing $m ..." >&2; plans_ls "$m.before"; probe_mode "$m"; plans_ls "$m.after"; done
  echo "probing headless-p ..." >&2; probe_headless
  write_record
  finish_record
  tail -n 1 "$REC"; echo "record: $REC"
  if [ -n "$MISSING" ]; then echo "INCOMPLETE:$MISSING" >&2; exit 3; fi
}
main
