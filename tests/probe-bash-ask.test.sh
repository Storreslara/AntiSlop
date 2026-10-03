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

for f in gate display_and_decline finish_record unseen; do eval "$(extract "$f")"; done
for f in row miss yn; do eval "$(oneline "$f")"; done
tm() { printf '%s\n' "$*" >> "$T/tm.log"; }
wait_for() { return "${WAIT_RC:-0}"; }
sleep() { :; }
cleanup() { :; }
dialog() { printf '%s\n' "$DIALOG"; }

DATE=2026-10-02
rows_for() { printf 'Probe row: %s prompt-rendered %s observed\nDisplay row: %s full-heredoc-visible yes %s observed\nDecline row: %s file-absent yes %s observed\n' "$1" "$DATE" "$1" "$DATE" "$1" "$DATE"; }
pre() { # modes... : pre-appendix text
  local m; printf '# Probe\n\n## Rows\n\n```\n'
  for m in "$@"; do rows_for "$m"; done
  printf 'Info row: plan not-driven %s informational\n```\n\n## Cleanup\n\nprose\n\n## Appendix: raw captured panes\n\n### default\n\n```\npane text\n' "$DATE"
}
yes3() { printf 'Cleanup check: scratch-removed yes\nCleanup check: repo-hooks-probe-free yes\nCleanup check: repo-hook-surface-clean yes\n'; }
grade() { gate "$1"; }
own() { grep '^Ship gate:' "$1" | tail -1 | sed 's/^Ship gate: //'; }

# (T1) committed-record re-grade
{ pre default acceptEdits auto; printf '```\n\n## Cleanup checks\n\n'; yes3; printf '\nShip gate: GREEN\n'; } > "$T/r1.md"
chk "T1 full-layout record" GREEN "$(grade "$T/r1.md")"
chk "T1 equals own Ship gate" "$(own "$T/r1.md")" "$(grade "$T/r1.md")"
# (T1b) when the committed record exists
REC1=docs/experiments/2026-10-01-probe-bash-ask.md
if [ -f "$REC1" ]; then chk "T1b committed record" "$(own "$REC1")" "$(grade "$REC1")"
else skp "T1b record" "no committed record"; fi

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
for n in gate display_and_decline finish_record unseen; do
  extract "$n" > "$T/x.sh"
  first=$(head -n 1 "$T/x.sh"); last=$(tail -n 1 "$T/x.sh")
  case "$first" in "$n() {"*) chk "T8 $n first line" y y;; *) chk "T8 $n first line" y n;; esac
  chk "T8 $n last line" "}" "$last"
  bash -n "$T/x.sh" 2>/dev/null; chk "T8 $n bash -n" 0 "$?"
  new=$(bash -c 'before=$(declare -F | sort); source "$1"; after=$(declare -F | sort); comm -13 <(echo "$before") <(echo "$after")' _ "$T/x.sh")
  chk "T8 $n defines only itself" "declare -f $n" "$new"
done

# (T9) closing EOF and decline
SCRATCH="$T/scr9"; mkdir -p "$SCRATCH"
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

echo "probe-bash-ask tests: $ok ok, $bad failed, $skip skipped (a skip is not a pass)"
[ "$bad" -eq 0 ]
