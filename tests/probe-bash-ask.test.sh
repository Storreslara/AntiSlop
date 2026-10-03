#!/usr/bin/env bash
# Offline tests for scripts/probe-bash-ask.sh: extracted functions only, never claude or tmux.
set -uo pipefail
cd "$(dirname "$0")/.."
P=${PROBE_UNDER_TEST:-scripts/probe-bash-ask.sh}
extract() { sed -n "/^$1()/,/^}/p" "$P"; }
oneline() { sed -n "/^$1()/p" "$P"; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=0; bad=0; skip=0
chk() { # label expected actual
  local id=${1%% *} rest=${1#* }
  if [ "$2" = "$3" ]; then echo "OK   ($id) $rest"; ok=$((ok + 1)); else echo "FAIL ($id) $rest: expected [$2] got [$3]"; bad=$((bad + 1)); fi
}
skp() { echo "SKIP (${1%% *}) ${1#* } $2"; skip=$((skip + 1)); }

for f in gate display_and_decline finish_record unseen write_record write_appendix; do eval "$(extract "$f")"; done
for f in row miss yn mode_version ver_of; do eval "$(oneline "$f")"; done
tm() { printf '%s\n' "$*" >> "$T/tm.log"; }
wait_for() { return "${WAIT_RC:-0}"; }
sleep() { :; }
cleanup() { :; }
dialog() { printf '%s\n' "$DIALOG"; }

DATE=2026-10-02
rows_for() { printf 'Probe row: %s prompt-rendered %s observed\nDisplay row: %s full-heredoc-visible yes %s observed\nDecline row: %s file-absent yes %s observed\n' "$1" "$DATE" "$1" "$DATE" "$1" "$DATE"; }
good_dialog() { printf '%s\n' ' Bash command' '' "   cat > out.txt <<'EOF'" '   line-1' '   line-2' '   line-3' '   line-4' '   line-5' '   line-6-END' '   EOF' '' ' Do you want to proceed?'; }
dblock() { # mode [content] : one length-prefixed dialog block
  local c; c=${2-$(good_dialog)}
  printf '\n### dialog: %s %s lines, claude 2.1.288 (Claude Code)\n```\n%s\n```\n' "$1" "$(printf '%s\n' "$c" | wc -l)" "$c"
}
pre() { # modes... : rows for the modes, dialog blocks for $DM (default: the same modes), then an open raw pane
  local m; printf '# Probe\n\n## Rows\n\n```\n'
  for m in "$@"; do rows_for "$m"; done
  printf 'Info row: plan not-driven %s informational\n```\n\n## Cleanup\n\nprose\n\n## Appendix: dialog blocks and raw captured panes\n' "$DATE"
  for m in ${DM-$@}; do dblock "$m"; done
  printf '\n### default (claude 2.1.288 (Claude Code))\n\n```\npane text\n'
}
yes3() { printf 'Cleanup check: scratch-removed yes\nCleanup check: repo-hooks-probe-free yes\nCleanup check: repo-hook-surface-clean yes\n'; }
grade() { gate "$1"; }
own() { grep '^Ship gate:' "$1" | tail -1 | sed 's/^Ship gate: //'; }

# (T1) committed-record re-grade
{ pre default acceptEdits auto; printf '```\n\n## Cleanup checks\n\n'; yes3; printf '\nShip gate: GREEN\n'; } > "$T/r1.md"
chk "T1 full-layout record" GREEN "$(grade "$T/r1.md")"
chk "T1 equals own Ship gate" "$(own "$T/r1.md")" "$(grade "$T/r1.md")"
# (T1b) committed record: compared only once it is new-format (has dialog blocks); an old-format record SKIPs, never passes
REC1=docs/experiments/2026-10-01-probe-bash-ask.md
if [ ! -f "$REC1" ]; then skp "T1b record" "no committed record"
elif ! grep -qx '## Appendix: dialog blocks and raw captured panes' "$REC1"; then
  skp "T1b committed record" "OLD FORMAT: no dialog blocks, so it cannot be re-graded (the new gate grades it RED); superseded by the operator's re-run"
else chk "T1b committed record (new format) equals own Ship gate" "$(own "$REC1")" "$(grade "$REC1")"; fi

# (T2) no-heading appendix tail
{ pre default acceptEdits auto; yes3; printf '```\n'; } > "$T/r2.md"
chk "T2 no heading, appendix-only yes lines" RED "$(grade "$T/r2.md")"

# (T3) heading forged inside a pane
{ pre default acceptEdits auto; printf '## Cleanup checks\n\n'; yes3; printf '```\n'; } > "$T/r3.md"
chk "T3 heading forged inside pane" RED "$(grade "$T/r3.md")"

# (T4) forged Cleanup lines
{ pre default acceptEdits auto; yes3; printf '```\n\n## Cleanup checks\n\nCleanup check: scratch-removed no\nCleanup check: repo-hooks-probe-free yes\nCleanup check: repo-hook-surface-clean yes\n'; } > "$T/r4a.md"
chk "T4a appendix yes, real block no" RED "$(grade "$T/r4a.md")"
{ pre default acceptEdits auto; printf '```\n\n## Cleanup checks\n\nCleanup check: scratch-removed yes\nCleanup check: scratch-removed yes\nCleanup check: repo-hooks-probe-free yes\nCleanup check: repo-hook-surface-clean yes\n'; } > "$T/r4b.md"
chk "T4b scratch-removed twice" RED "$(grade "$T/r4b.md")"

# (T5) missing acceptEdits row
{ pre default auto; printf '```\n\n## Cleanup checks\n\n'; yes3; } > "$T/r5.md"
chk "T5 missing acceptEdits rows" RED "$(grade "$T/r5.md")"

# (T6) hooks.json via finish_record
ROOT="$T/repo"; mkdir -p "$ROOT/hooks"; git -C "$ROOT" init -q
git -C "$ROOT" config user.email t@t; git -C "$ROOT" config user.name t
: > "$ROOT/keep"; git -C "$ROOT" add keep; git -C "$ROOT" commit -qm init
SCRATCH="$T/scratch"; REC="$T/rec6.md"
run6() { { pre default acceptEdits auto; printf '```\n'; } > "$REC"; finish_record 2>/dev/null; }
probe_free() { grep '^Cleanup check: repo-hooks-probe-free ' "$REC" | tail -1 | sed 's/.* //'; }
run6; chk "T6 hooks.json missing -> no" no "$(probe_free)"
chk "T6 missing -> Ship gate RED" "Ship gate: RED" "$(tail -n 1 "$REC")"
printf '{"hooks":{}}\n' > "$ROOT/hooks/hooks.json"; git -C "$ROOT" add hooks/hooks.json; git -C "$ROOT" commit -qm hooks
run6; chk "T6 present probe-free -> yes" yes "$(probe_free)"
chk "T6 present probe-free -> GREEN" "Ship gate: GREEN" "$(tail -n 1 "$REC")"
printf '{"hooks":{"probe":1}}\n' > "$ROOT/hooks/hooks.json"; git -C "$ROOT" commit -qam probe
run6; chk "T6 containing probe -> no" no "$(probe_free)"
printf '{"hooks":{}}\n' > "$ROOT/hooks/hooks.json"; git -C "$ROOT" commit -qam clean; chmod 000 "$ROOT/hooks/hooks.json"
if [ "$(id -u)" = 0 ]; then skp "T6 unreadable" "running as root"
else run6; chk "T6 unreadable -> no" no "$(probe_free)"; fi
chmod 644 "$ROOT/hooks/hooks.json"

# (T7) plan Info row forms
ROWS=""; MISSING=""; unseen plan readiness 2>/dev/null
chk "T7 unseen plan appends Info row" "Info row: plan not-driven $DATE informational" "${ROWS%$'\n'}"
chk "T7 unseen plan no MISSING" "" "$MISSING"
ROWS=""; MISSING=""; unseen default x 2>/dev/null
chk "T7 unseen default appends no row" "" "$ROWS"
case "$MISSING" in *default*) chk "T7 unseen default in MISSING" y y;; *) chk "T7 unseen default in MISSING" y n;; esac
sed "s/^Info row: plan not-driven .*/Info row: plan denied $DATE observed informational/" "$T/r1.md" > "$T/r7a.md"
chk "T7 plan observed Info row still GREEN" GREEN "$(grade "$T/r7a.md")"
grep -v '^Info row: plan' "$T/r1.md" > "$T/r7b.md"
chk "T7 no plan line still GREEN" GREEN "$(grade "$T/r7b.md")"
if grep -qF 'row "Info row: plan $v $DATE observed informational"' "$P"; then chk "T7 static plan row line" y y; else chk "T7 static plan row line" y n; fi

# (T8) sed extraction is self-contained
for n in gate display_and_decline finish_record unseen write_record write_appendix; do
  extract "$n" > "$T/x.sh"
  first=$(head -n 1 "$T/x.sh"); last=$(tail -n 1 "$T/x.sh")
  case "$first" in "$n() {"*) chk "T8 $n first line" y y;; *) chk "T8 $n first line" y n;; esac
  chk "T8 $n last line" "}" "$last"
  bash -n "$T/x.sh" 2>/dev/null; chk "T8 $n bash -n" 0 "$?"
  new=$(bash -c 'before=$(declare -F | sort); source "$1"; after=$(declare -F | sort); comm -13 <(echo "$before") <(echo "$after")' _ "$T/x.sh")
  chk "T8 $n defines only itself" "declare -f $n" "$new"
done

# (T9) closing EOF and decline
SCRATCH="$T/scr9"; RAW="$T/raw9"; mkdir -p "$SCRATCH" "$RAW"
lines() { printf '%s\n' ' Bash command' "cat > out.txt <<'EOF'" line-1 line-2 line-3 line-4 line-5 line-6-END; }
vis() { ROWS=""; MISSING=""; DIALOG="$1"; display_and_decline default s 2>/dev/null; grep -o 'full-heredoc-visible [a-z]*' <<<"$ROWS" | sed 's/.* //'; }
chk "T9 bare EOF" yes "$(vis "$(lines; echo EOF)")"
chk "T9 framed EOF" yes "$(vis "$(lines; echo '│ EOF │')")"
chk "T9 no closing EOF" no "$(vis "$(lines)")"
chk "T9 EOF before line-6-END only" no "$(vis "$(lines | sed 's/^line-6-END$/EOF\nline-6-END/')")"
chk "T9 EOFX" no "$(vis "$(lines; echo EOFX)")"
chk "T9 line-3 missing" no "$(vis "$(lines | grep -v '^line-3$'; echo EOF)")"
dec() { grep -o 'Decline row: default file-absent [a-z]*' <<<"$ROWS" | sed 's/.* //'; }
DIALOG="$(lines; echo EOF)"
rm -f "$SCRATCH/out.txt"; ROWS=""; MISSING=""; display_and_decline default s 2>/dev/null
chk "T9 out.txt absent -> yes" yes "$(dec)"
: > "$SCRATCH/out.txt"; ROWS=""; MISSING=""; display_and_decline default s 2>/dev/null
chk "T9 out.txt present -> no" no "$(dec)"
rm -f "$SCRATCH/out.txt"; ROWS=""; MISSING=""; WAIT_RC=1 display_and_decline default s 2>/dev/null
chk "T9 WAIT_RC=1 no Decline row" "" "$(dec)"
chk "T9 WAIT_RC=1 MISSING non-empty" y "$([ -n "$MISSING" ] && echo y || echo n)"

# (T10) the dialog block grading used is saved, captured BEFORE the decline key
tm() { printf '%s\n' "$*" >> "$T/tm.log"; case "$*" in *send-keys*) DIALOG="Interrupted";; esac; }   # the dialog vanishes on decline
rm -f "$RAW/default.dialog"; DIALOG="$(lines; echo EOF)"; ROWS=""; MISSING=""; display_and_decline default s 2>/dev/null
chk "T10 dialog saved before decline" "$(lines; echo EOF)" "$(cat "$RAW/default.dialog" 2>/dev/null)"
DIALOG=""; ROWS=""; MISSING=""; display_and_decline auto s 2>/dev/null
chk "T10 empty dialog saved as empty file" 0 "$([ -f "$RAW/auto.dialog" ] && wc -c < "$RAW/auto.dialog" || echo missing)"
tm() { printf '%s\n' "$*" >> "$T/tm.log"; }

# (T11) gate: each gated mode's own dialog block must carry the evidence
tail_ok() { printf '```\n\n## Cleanup checks\n\n'; yes3; }
g11() { { "$@"; tail_ok; } > "$T/r11.md"; grade "$T/r11.md"; }
chk "T11 good full record" GREEN "$(g11 pre default acceptEdits auto)"
chk "T11a GREEN rows, no acceptEdits dialog block" RED "$(DM="default auto" g11 pre default acceptEdits auto)"
chk "T11a GREEN rows, no dialog blocks at all" RED "$(DM="" g11 pre default acceptEdits auto)"
bad6() { DM="default auto" pre default acceptEdits auto | sed '/^### default (/,$d'; dblock acceptEdits "$(good_dialog | grep -v line-6-END)"; printf '\n### default\n\n```\npane\n'; }
chk "T11b acceptEdits block lacks line-6-END" RED "$(g11 bad6)"
badeof() { DM="default auto" pre default acceptEdits auto | sed '/^### default (/,$d'; dblock acceptEdits "$(good_dialog | grep -v '^   EOF$')"; printf '\n### default\n\n```\npane\n'; }
chk "T11c acceptEdits block lacks closing EOF line" RED "$(g11 badeof)"
nomark() { DM="default auto" pre default acceptEdits auto | sed '/^### default (/,$d'; dblock acceptEdits "$(good_dialog | grep -v proceed)"; printf '\n### default\n\n```\npane\n'; }
chk "T11c acceptEdits block lacks the dialog marker" RED "$(g11 nomark)"
chk "T11d default's block cannot back acceptEdits (two default blocks)" RED "$(DM="default default auto" g11 pre default acceptEdits auto)"
dup() { DM="default acceptEdits auto" pre default acceptEdits auto | sed '/^### default (/,$d'; dblock acceptEdits "$(good_dialog | grep -v line-6-END)"; printf '\n### default\n\n```\npane\n'; }
chk "T11d two acceptEdits blocks (one bad) is ambiguous" RED "$(g11 dup)"
forged_pane() { DM="default auto" pre default acceptEdits auto; printf '### dialog: acceptEdits 12 lines, claude x\n```\n'; good_dialog; printf '```\n'; }
chk "T11e forged dialog heading inside a raw pane" RED "$(g11 forged_pane)"
forged_break() { DM="default auto" pre default acceptEdits auto; printf '```\n\n### dialog: acceptEdits 12 lines, claude x\n```\n'; good_dialog; }
chk "T11e forged heading after a fence break in a raw pane" RED "$(g11 forged_break)"
forged_text() { DM="default auto" pre default acceptEdits auto; printf '\n### acceptEdits\n\n```\n'; good_dialog; }
chk "T11f dialog text in acceptEdits' raw pane, no block" RED "$(g11 forged_text)"
inner() { DM="default auto" pre default acceptEdits auto | sed '/^### default (/,$d'; dblock dontAsk "$(good_dialog; printf '```\n\n### dialog: acceptEdits 12 lines, claude x\n```\n'; good_dialog)"; printf '\n### default\n\n```\npane\n'; }
chk "T11g forged acceptEdits block inside dontAsk's dialog text" RED "$(g11 inner)"
short() { DM="default auto" pre default acceptEdits auto | sed '/^### default (/,$d'; printf '\n### dialog: acceptEdits 3 lines, claude x\n```\n'; good_dialog; printf '```\n'; }
chk "T11h block shorter than its declared line count" RED "$(g11 short)"
chk "T11 rows above the appendix still required" RED "$(DM="default acceptEdits auto" g11 pre default auto)"

# (T12) writer round trip: write_record + finish_record grade from the saved dialogs, per-mode versions
ROOT="$T/repo"; SCRATCH="$T/scr12"; RAW="$SCRATCH/raw"; REC="$T/rec12.md"
MODES="default plan acceptEdits auto dontAsk bypassPermissions"; HL_CLASSIFIER=x; MISSING=""
cleanup() { rm -rf "$SCRATCH"; }
run12() { # version-per-mode...: writes and grades a record
  local m v; rm -rf "$SCRATCH"; mkdir -p "$RAW"; ROWS=""; VERSION="2.1.287 (Claude Code)"
  for m in default acceptEdits auto; do ROWS="$ROWS$(rows_for "$m")"$'\n'; good_dialog > "$RAW/$m.dialog"; done
  for m in $MODES headless; do v=$1; shift; [ "$v" = - ] || printf '%s\n' "$v" > "$RAW/$m.version"; printf 'pane %s\n' "$m" > "$RAW/$m.txt"; done
  write_record; finish_record 2>/dev/null
}
same="2.1.287 (Claude Code)"; other="2.1.288 (Claude Code)"
run12 "$same" "$same" "$same" "$same" "$same" "$same" "$same"
chk "T12 written record grades GREEN" "Ship gate: GREEN" "$(tail -n 1 "$REC")"
chk "T12 same versions: no Version note" 0 "$(grep -c '^Version note:' "$REC")"
chk "T12 dialog block header carries the mode's version" 1 "$(grep -cxF "### dialog: auto 12 lines, claude $same" "$REC")"
run12 "$same" "$same" "$other" "$other" "$other" "$other" "$other"
chk "T12 differing versions: Version note" 1 "$(grep -c '^Version note: .*acceptEdits=2\.1\.288 (Claude Code)' "$REC")"
chk "T12 top-level Version stays the setup reading" 1 "$(grep -cF "reports \`$same\`" "$REC")"
chk "T12 raw pane header carries the mode's version" 1 "$(grep -cxF "### dontAsk (claude $other)" "$REC")"
run12 "$same" - "$same" "$same" "$same" "$same" "$same"
chk "T12 unreadable version said, never inferred" 1 "$(grep -cxF "### plan (claude unreadable)" "$REC")"
rm -rf "$SCRATCH"; mkdir -p "$RAW"; ROWS=""; for m in default acceptEdits auto; do ROWS="$ROWS$(rows_for "$m")"$'\n'; good_dialog > "$RAW/$m.dialog"; done
good_dialog | grep -v line-6-END > "$RAW/acceptEdits.dialog"; write_record; finish_record 2>/dev/null
chk "T12 written record with a bad acceptEdits dialog grades RED" "Ship gate: RED" "$(tail -n 1 "$REC")"
claude() { return 1; }; RAW="$T/raw12v"; mkdir -p "$RAW"; mode_version default
chk "T12 mode_version unreadable when claude fails" unreadable "$(cat "$RAW/default.version")"
claude() { echo "9.9.9 (Claude Code)"; }; mode_version default
chk "T12 mode_version records the reading" "9.9.9 (Claude Code)" "$(cat "$RAW/default.version")"
unset -f claude; cleanup() { :; }

# (T13) Method and Status say only what the script verifies
if grep -qF 'rows are `observed` only where derived from the captured pane text in the appendix' "$P"; then chk "T13 old over-claiming sentence gone" y n; else chk "T13 old over-claiming sentence gone" y y; fi
if grep -qF 'dialog block' "$P" && grep -qF 'after the decline' "$P" && grep -qF 'JSON output' "$P"; then chk "T13 Method names each row's evidence" y y; else chk "T13 Method names each row's evidence" y n; fi

echo "probe-bash-ask tests: $ok ok, $bad failed, $skip skipped (a skip is not a pass)"
[ "$bad" -eq 0 ]
