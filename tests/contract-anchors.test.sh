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
exit "$fail"
