#!/usr/bin/env bash
# epa-3: the escalation packet viewer (view.sh) embedded in four instruction
# sources + two mirrors. Hermetic: stubs and fixtures live under mktemp -d.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

copies="agents/reviewer.md templates/persona-protocol.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc .claude/agents/reviewer.md .claude/persona-protocol.md"

extract() {
  awk '/^<!-- view.sh:end -->$/{f=0} f&&!/^```/{print} /^<!-- view.sh:begin -->$/{f=1}' "$1"
}

# T1 - six copies, non-empty, byte-identical
ref=""
for f in $copies; do
  extract "$f" > "$tmp/ext"
  if [ ! -s "$tmp/ext" ]; then bad "T1 $f: no viewer block"; continue; fi
  if [ -z "$ref" ]; then ref="$f"; cp "$tmp/ext" "$tmp/ref"
  elif cmp -s "$tmp/ext" "$tmp/ref"; then pass "T1 $f identical to $ref"
  else bad "T1 $f differs from $ref"; fi
done
[ -s "$tmp/ref" ] || { echo "FAIL no reference block; cannot run T2-T9"; exit 1; }
script="$tmp/ref"

# T1b - the copies equal the canonical viewer
cat > "$tmp/canon" <<'VIEW_SH_CANONICAL'
#!/bin/sh
# Escalation packet viewer: renders CHANGES.md and EXAMPLES.md in colour when
# glow, bat or rich is installed, else prints them plain. Read-only.
dir=$(cd "$(dirname "$0")" && pwd)
for f in CHANGES.md EXAMPLES.md; do
  p="$dir/$f"
  [ -f "$p" ] || continue
  if command -v glow >/dev/null 2>&1 && glow "$p"; then :
  elif command -v bat >/dev/null 2>&1 && bat --paging=never -l md "$p"; then :
  elif command -v batcat >/dev/null 2>&1 && batcat --paging=never -l md "$p"; then :
  elif command -v rich >/dev/null 2>&1 && rich --markdown "$p"; then :
  else cat "$p"
  fi
done
exit 0
VIEW_SH_CANONICAL
if cmp -s "$tmp/ref" "$tmp/canon"; then pass "T1b copies equal the canonical viewer"
else bad "T1b copies differ from the canonical viewer"; fi

# T2 - shebang, ASCII, no forbidden tokens
[ "$(head -n1 "$script")" = '#!/bin/sh' ] && pass "T2 shebang" || bad "T2 shebang"
if LC_ALL=C grep -q '[^ -~	]' "$script"; then bad "T2 non-ASCII byte"; else pass "T2 ASCII only"; fi
if grep -qE 'DECISION|human-review' "$script"; then bad "T2 forbidden token"; else pass "T2 no DECISION / human-review"; fi

# fixture packet + PATH dirs
sh_bin="$(command -v sh)"; cat_bin="$(command -v cat)"; dn_bin="$(command -v dirname)"
mkbin() {
  mkdir -p "$tmp/$1"
  ln -s "$sh_bin" "$tmp/$1/sh"; ln -s "$cat_bin" "$tmp/$1/cat"; ln -s "$dn_bin" "$tmp/$1/dirname"
}
stub() { # $1 bindir $2 name $3 exit
  printf '#!/bin/sh\necho "%s:$*"\nexit %s\n' "$(echo "$2" | tr a-z A-Z)" "$3" > "$tmp/$1/$2"
  chmod +x "$tmp/$1/$2"
}
pkt="$tmp/pkt"; mkdir -p "$pkt" "$tmp/elsewhere"
cp "$script" "$pkt/view.sh"; chmod +x "$pkt/view.sh"
printf '# changes raw\nline c\n' > "$pkt/CHANGES.md"
printf '# examples raw\nline e\n' > "$pkt/EXAMPLES.md"
runv() { # $1 bindir ; sets out, rc
  rc=0
  out="$(cd "$tmp/elsewhere" && env -i PATH="$tmp/$1" "$sh_bin" "$pkt/view.sh" 2>"$tmp/err")" || rc=$?
}

# T3 - no renderers -> plain cat of both files, rc 0
mkbin none; runv none
[ "$out" = "$(cat "$pkt/CHANGES.md" "$pkt/EXAMPLES.md")" ] && [ "$rc" = 0 ] \
  && pass "T3 plain cat fallback" || bad "T3 plain cat fallback (rc=$rc)"

# T4 - glow stub: two GLOW lines, no raw text
mkbin glow; stub glow glow 0; runv glow
[ "$(printf '%s\n' "$out" | grep -c '^GLOW:')" = 2 ] && ! printf '%s' "$out" | grep -q 'raw' && [ "$rc" = 0 ] \
  && pass "T4 glow used for both files" || bad "T4 glow (rc=$rc): $out"

# T5 - failing glow falls through to bat with --paging=never -l md
mkbin bat; stub bat glow 1; stub bat bat 0; runv bat
[ "$(printf '%s\n' "$out" | grep -c '^BAT:--paging=never -l md ')" = 2 ] && ! printf '%s' "$out" | grep -q 'raw' \
  && pass "T5 failing glow falls through to bat" || bad "T5 bat fallthrough: $out"

# T6 - only batcat
mkbin batcat; stub batcat batcat 0; runv batcat
[ "$(printf '%s\n' "$out" | grep -c '^BATCAT:--paging=never -l md ')" = 2 ] \
  && pass "T6 batcat used" || bad "T6 batcat: $out"

# T7 - only rich
mkbin rich; stub rich rich 0; runv rich
[ "$(printf '%s\n' "$out" | grep -c '^RICH:--markdown ')" = 2 ] \
  && pass "T7 rich --markdown used" || bad "T7 rich: $out"

# O1-O4 - fallback order: with two renderers on PATH only the earlier one may run
cnt() { printf '%s\n' "$out" | grep -c "^$1:"; }
mkbin o1; stub o1 glow 0; stub o1 bat 0; runv o1
[ "$(cnt GLOW)" = 2 ] && [ "$(cnt BAT)" = 0 ] \
  && pass "O1 glow before bat" || bad "O1 glow before bat: $out"
mkbin o2; stub o2 bat 0; stub o2 batcat 0; runv o2
[ "$(cnt BAT)" = 2 ] && [ "$(cnt BATCAT)" = 0 ] \
  && pass "O2 bat before batcat" || bad "O2 bat before batcat: $out"
mkbin o3; stub o3 batcat 0; stub o3 rich 0; runv o3
[ "$(cnt BATCAT)" = 2 ] && [ "$(cnt RICH)" = 0 ] \
  && pass "O3 batcat before rich" || bad "O3 batcat before rich: $out"
mkbin o4; stub o4 rich 0; runv o4
[ "$(cnt RICH)" = 2 ] && ! printf '%s' "$out" | grep -q 'raw' \
  && pass "O4 rich before cat" || bad "O4 rich before cat: $out"

# T8 - EXAMPLES.md absent, other cwd, absolute path
rm "$pkt/EXAMPLES.md"; runv none
[ "$out" = "$(cat "$pkt/CHANGES.md")" ] && [ "$rc" = 0 ] && [ ! -s "$tmp/err" ] \
  && pass "T8 missing EXAMPLES.md skipped, rc 0, stderr empty" || bad "T8 missing EXAMPLES.md (rc=$rc, stderr=$(cat "$tmp/err"))"

# T9 - the decision gate lets a reviewer heredoc-write the viewer
proj="$tmp/proj"; mkdir -p "$proj/.claude/human-review/u1"
cmd="$(printf 'cat > .claude/human-review/u1/view.sh <<'"'"'EOF'"'"'\n%s\nEOF\nchmod +x .claude/human-review/u1/view.sh' "$(cat "$script")")"
rc=0
jq -n --arg a antislop:reviewer --arg c "$cmd" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}' \
  | CLAUDE_PROJECT_DIR="$proj" bash hooks/scripts/human-decision-gate.sh >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] && pass "T9 decision gate allows the viewer write" || bad "T9 gate rc=$rc"

# T10 - orchestrator steps 2 and 3 both strip the Read tool's line-number prefixes
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  n="$(tr -s ' \n' ' ' < "$f" | grep -o "without the Read tool's line-number prefixes" | wc -l)"
  [ "$n" = 2 ] && pass "T10 $f: prefix clause in both steps" || bad "T10 $f: clause count $n, expected 2"
done

exit "$fail"
