#!/usr/bin/env bash
# contract-anchors.js (rp-u6): a contract's anchors and before: payloads are checked against the files they
# edit, in order, after the queued --chain contracts. Fixtures are written to a temp dir.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CA="$ROOT/bin/contract-anchors.js"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/r"
printf 'alpha\nbeta\ngamma\n  indented line\nbeta\n' > "$T/r/a.txt"
edit() { printf '%s. file: `%s`\n   anchor: %s\n   indent: %s\n' "$1" "$2" "$3" "$4"; }
head_() { printf 'Unit: x\n\n## Affected files\n%s\n\n## Ordered edits\n' "$1"; }
{ head_ '- `a.txt` (anchor: line matching `alpha`)'
  edit 1 a.txt 'line matching `alpha`' 0; printf '   before: `alpha`\n   after: `ALPHA`\n'
  edit 2 a.txt 'line matching `ALPHA`' 0; printf '   insert-after: `delta`\n'
  edit 3 a.txt 'line matching `indented`' 2; printf '   before:\n~~~\n  indented line\n~~~\n   after:\n~~~\n  indented line two\n~~~\n'
  edit 4 a.txt 'line ending `amma`' 3; printf '   before:\n~~~\n   gamma\n~~~\n   after:\n~~~\n   GAMMA\n~~~\n'
  edit 5 a.txt 'line matching `beta`' 0; printf '   before:\n~~~\nGAMMA\n  indented line two\nbeta\n~~~\n   after:\n~~~\nGAMMA\n~~~\n'
  edit 6 n.txt 'new file' 0; printf '   insert-after: `new`\n'
  printf '7. command: `true`\n   expect: 0\n'; } > "$T/ok.md"
out="$(node "$CA" "$T/ok.md" --repo="$T/r")"; rc=$?
[ "$rc" = 0 ] && ok "(a) every check ok exits 0" || bad "(a) exit $rc: $out"
[ "$(printf '%s\n' "$out" | tail -n1)" = 'contract-anchors: ok checks=11 bad=0 unchecked=0' ] && ok "(a) summary" || bad "(a) summary: $(printf '%s\n' "$out" | tail -n1)"
printf '%s\n' "$out" | grep -qx 'anchor ok 2 a.txt' && ok "(b) a later edit sees an earlier one" || bad "(b) sequential edits"
printf '%s\n' "$out" | grep -qx 'before ok 4 a.txt' && ok "(c) payload matched after stripping indent: N" || bad "(c) indent strip"
printf '%s\n' "$out" | grep -qx 'anchor ok 5 a.txt' && ok "(d) a repeated anchor inside a unique payload is ok" || bad "(d) covered anchor"
{ head_ '- `a.txt` (anchor: line matching `zeta`)'
  edit 1 a.txt 'line matching `beta`' 0; printf '   insert-after: `x`\n'
  edit 2 a.txt 'line matching `alpha`' 0; printf '   before: `omega`\n   after: `x`\n'
  edit 3 a.txt 'new file' 0; printf '   insert-after: `x`\n'
  edit 4 b.txt 'line matching `x`' 0; printf '   insert-after: `x`\n'; } > "$T/bad.md"
out="$(node "$CA" "$T/bad.md" --repo="$T/r")"; rc=$?
[ "$rc" = 1 ] && ok "(e) a bad check exits 1" || bad "(e) exit $rc"
for l in 'anchor ambiguous 1 a.txt' 'before missing 2 a.txt' 'new exists 3 a.txt' 'file missing 4 b.txt' 'anchor missing af a.txt' 'contract-anchors: fail checks=6 bad=5 unchecked=0'; do
  printf '%s\n' "$out" | grep -qxF -- "$l" && ok "(e) $l" || bad "(e) missing line: $l"
done
{ head_ '- `a.txt` (anchor: line matching `gamma`)'; edit 1 a.txt 'line matching `gamma`' 0; printf '   before: `gamma`\n   after: `GAMMA`\n'; } > "$T/q.md"
{ head_ '- `a.txt` (anchor: line matching `alpha`)'; edit 1 a.txt 'line matching `GAMMA`' 0; printf '   before: `GAMMA`\n   after: `G`\n'; } > "$T/needs.md"
node "$CA" "$T/needs.md" --repo="$T/r" >/dev/null; rc=$?
[ "$rc" = 1 ] && ok "(f) a line only a queued unit creates is missing without --chain" || bad "(f) rc=$rc"
out="$(node "$CA" "$T/needs.md" --repo="$T/r" --chain="$T/q.md")"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qxF "chain ok - $T/q.md" && ok "(f) ... and ok after it" || bad "(f) with chain rc=$rc: $out"
out="$(node "$CA" "$T/q.md" --repo="$T/r" --chain="$T/q.md")"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -qx 'before missing 1 a.txt' && ok "(g) a line a queued unit rewrites is missing" || bad "(g) rc=$rc"
printf 'Unit: x\n\n## Objective\nnone\n' > "$T/none.md"
node "$CA" >/dev/null 2>&1; r1=$?
node "$CA" "$T/ok.md" --repo "$T/r" >/dev/null 2>&1; r2=$?
node "$CA" "$T/none.md" >/dev/null 2>&1; r3=$?
node "$CA" "$T/missing.md" >/dev/null 2>&1; r4=$?
node "$CA" "$T/ok.md" --repo="$T/r" --chain="$T/missing.md" >/dev/null 2>&1; r5=$?
[ "$r1$r2$r3$r4$r5" = 22222 ] && ok "(h) usage and read errors exit 2" || bad "(h) exits $r1 $r2 $r3 $r4 $r5"
u="$(node "$CA" 2>&1 >/dev/null)"
case "$u" in *'usage: contract-anchors.js <contract> [--repo=<dir>] [--chain=<contract>]...'*) ok "(h) usage line" ;; *) bad "(h) usage line: $u" ;; esac
[ -x "$CA" ] && ok "(i) executable" || bad "(i) not executable"
# rp-u6 fix 1: the outcome table (script header) as a generated matrix, one node run per case.
mkdir -p "$T/m"
hl() { case "$1" in matching) echo "a$2 foo b$2" ;; ending) echo "a$2 foo" ;; starting) echo "foo b$2" ;; esac; }
mk_file() { # kind hits [dup]: hit lines, decoys for the other kinds, two plain lines
  local i; : > "$T/m/a.txt"
  for ((i = 1; i <= $2; i++)); do hl "$1" "$i" >> "$T/m/a.txt"; done
  [ -n "${3:-}" ] && hl "$1" 1 >> "$T/m/a.txt"
  case "$1" in ending) printf 'foo b9\na9 foo b9\n' ;; starting) printf 'a9 foo\na9 foo b9\n' ;; esac >> "$T/m/a.txt"
  printf 'plain line\ntail line\n' >> "$T/m/a.txt"
}
one() { { head_ "$1"; edit 1 "$2" "$3" 0; printf '%b' "$4"; } > "$T/c.md"; } # bullet file anchor payload
sum() { echo "contract-anchors: $1 checks=$2 bad=$3 unchecked=${4:-0}"; }
expect() { # name rc want-stdout [more node args]
  local out r; out="$(node "$CA" "$T/c.md" --repo="$T/m" "${@:4}" 2>"$T/err")"; r=$?
  [ "$r" = "$2" ] && [ "$out" = "$3" ] && ok "$1" || bad "$1: rc=$r got [$(printf %s "$out" | tr '\n' '|')]"
}
rc_is() { node "$CA" "$T/c.md" --repo="$T/m" "${@:3}" >/dev/null 2>"$T/err"; [ "$?" = "$2" ] && ok "$1" || bad "$1"; }
oracle() { # payload hits -> "<anchor status> <payload status or ->"
  case "$1:$2" in
    P0:0) echo "missing -" ;; P0:1) echo "ok -" ;; P0:2) echo "ambiguous -" ;;
    P1:0|P4:0|P2:0) echo "missing ok" ;; P1:1|P4:1|P2:1|P1:2|P4:2) echo "ok ok" ;; P2:2) echo "ambiguous ok" ;;
    P3:0) echo "missing missing" ;; P3:1) echo "ok missing" ;; P3:2) echo "ambiguous missing" ;;
    P5:2) echo "ambiguous ambiguous" ;; P6:2) echo "ambiguous ok" ;;
  esac
}
run_case() { # kind hits payload
  local k="$1" h="$2" p="$3" t a b exp key=before bads=0 n=1 x pay
  mk_file "$k" "$h" "$([ "$p" = P5 ] && echo dup)"; t="$(head -n1 "$T/m/a.txt")"
  case "$p" in P2) x='tail line' ;; P3) x="${t#?}" ;; P5) x="$(hl "$k" 1)" ;; *) x="$t" ;; esac
  case "$p" in
    P0) pay='   insert-after: `new line`\n' ;;
    P4) key=delete; pay="   delete: \`$x\`\n" ;;
    P6) pay="   before:\n~~~\n$(hl "$k" 1)\n$(hl "$k" 2)\n~~~\n   after: \`REPL\`\n" ;;
    *) pay="   before: \`$x\`\n   after: \`REPL\`\n" ;;
  esac
  one '- `a.txt`' a.txt "line $k \`foo\`" "$pay"
  read -r a b <<< "$(oracle "$p" "$h")"
  exp="anchor $a 1 a.txt"; [ "$a" != ok ] && bads=1
  [ "$b" != "-" ] && { exp="$exp"$'\n'"$key $b 1 a.txt"; n=2; [ "$b" != ok ] && bads=$((bads + 1)); }
  expect "(m) $k hits=$h $p" "$([ $bads = 0 ] && echo 0 || echo 1)" "$exp"$'\n'"$(sum "$([ $bads = 0 ] && echo ok || echo fail)" $n $bads)"
}
for k in matching ending starting; do
  for p in P0 P1 P2 P3 P4; do for h in 0 1 2; do run_case "$k" "$h" "$p"; done; done
  run_case "$k" 2 P5; run_case "$k" 2 P6
done
# (end of the generated matrix, rp-u6 fix 1)
for k in matching ending starting; do for h in 0 1 2; do # Affected-files anchors: kind x hits
  mk_file "$k" "$h"; w=ambiguous; [ "$h" = 0 ] && w=missing; [ "$h" = 1 ] && w=ok
  printf 'Unit: x\n\n## Affected files\n- `a.txt` (anchor: line %s `foo`)\n\n## Ordered edits\n1. command: `true`\n   expect: 0\n' "$k" > "$T/c.md"
  expect "(n) affected $k hits=$h" "$([ "$h" = 1 ] && echo 0 || echo 1)" "anchor $w af a.txt"$'\n'"$(sum "$([ "$h" = 1 ] && echo ok || echo fail)" 1 "$([ "$h" = 1 ] && echo 0 || echo 1)")"
done; done
printf 'Unit: x\n\n## Affected files\n- `n.txt` (anchor: new file, mode 755)\n- `a.txt` (anchor: new file)\n\n## Ordered edits\n1. file: `n.txt`\n   anchor: new file\n   insert-after: `x`\n2. file: `n.txt`\n   anchor: new file\n   insert-after: `y`\n' > "$T/c.md"
expect "(n) new file: absent ok; present or made by an earlier edit exists" 1 "new ok 1 n.txt
new exists 2 n.txt
new ok af n.txt
new exists af a.txt
$(sum fail 4 2)"
printf 'Unit: x\n\n## Ordered edits\n1. Rewrite the intro paragraph.\n2. file: a.txt\n   anchor: line matching `plain line`\n3. command: `true`\n   expect: 0\n' > "$T/c.md"
expect "(o) items with no backticked file: are unchecked" 0 "edit unchecked 1 -
edit unchecked 2 -
$(sum unchecked 2 0 2)"
grep -q 'WARNING 2 item' "$T/err" && ok "(o) ... and warn on stderr" || bad "(o) no stderr warning"
printf 'Unit: x\n\n## Ordered edits\n' > "$T/c.md"
expect "(o) an Ordered edits section with no items is unchecked" 0 "edit unchecked - -
$(sum unchecked 1 0 1)"
one '- `a.txt`' a.txt 'line matching `plain line`' '   before: plain line\n   after: `X`\n'
expect "(o) an unbackticked before: is unchecked" 0 "before unchecked 1 a.txt
anchor ok 1 a.txt
$(sum unchecked 2 0 1)"
one '- `a.txt`' a.txt 'line matching `plain line`' '   before: `plain line`\n   before: `tail line`\n   after: `X`\n'
expect "(p) a second before: in one edit is duplicate" 1 "before duplicate 1 a.txt
anchor ok 1 a.txt
before ok 1 a.txt
$(sum fail 3 1)"
printf 'use `x` here\nother\nrun --opt \\\nnext\n' > "$T/m/e.txt"
one '- `e.txt` (anchor: line matching `use \`x\` here`)' e.txt 'line matching `use \`x\` here`' '   insert-after: `x`\n'
expect "(q) an anchor literal with an escaped backtick is parsed" 0 "anchor ok 1 e.txt
anchor ok af e.txt
$(sum ok 2 0)"
one '- `e.txt` (anchor: line ending `--opt \`)' e.txt 'line ending `--opt \`' '   insert-after: `x`\n'
expect "(q) an anchor literal that ends in a backslash is read as written" 0 "anchor ok 1 e.txt
anchor ok af e.txt
$(sum ok 2 0)"
printf 'root:x\n' > "$T/outside.txt"; ln -sf ../outside.txt "$T/m/link.txt"; ln -sfn .. "$T/m/dl"
for f in ../outside.txt "$T/outside.txt" link.txt dl/new.txt; do
  one '- `a.txt`' "$f" 'line starting `root:`' '   insert-after: `x`\n'
  rc_is "(r) file: $f is outside the repo" 2; grep -q 'outside --repo' "$T/err" || bad "(r) message for $f: $(cat "$T/err")"
done
one '- `../outside.txt` (anchor: line starting `root:`)' a.txt 'line matching `tail line`' '   insert-after: `x`\n'
rc_is "(r) an Affected-files path outside the repo, exit 2" 2
one '- `a.txt`' ../outside.txt 'line starting `root:`' '   insert-after: `x`\n'; cp "$T/c.md" "$T/chain.md"
one '- `a.txt`' a.txt 'line matching `tail line`' '   insert-after: `x`\n'
rc_is "(r) a --chain contract's path outside the repo, exit 2" 2 --chain="$T/chain.md"
node "$CA" "$T/c.md" --repo="$T/none" >/dev/null 2>&1; [ "$?" = 2 ] && ok "(r) a --repo that does not exist exits 2" || bad "(r) missing repo"
exit "$fail"
