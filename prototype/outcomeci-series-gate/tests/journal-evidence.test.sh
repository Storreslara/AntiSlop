#!/usr/bin/env bash
# Exercises journal-evidence.sh against throwaway journals, plus a banner-deletion mutation case.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fmt="${JOURNAL_EVIDENCE_BIN:-$here/../journal-evidence.sh}"
export PATH="$HOME/.local/bin:$PATH"
failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
banner='## External run journal (NON-AUTHORITATIVE - evidence only)'

fail() { printf 'FAIL %s: %s\n' "$1" "$2"; failures=$((failures + 1)); }

# journal <trial-dir> <run-id> <json>
journal() {
  mkdir -p "$1/.outcomeci/.broker/$2"
  printf '%s\n' "$3" > "$1/.outcomeci/.broker/$2/journal.json"
}

# common <name> <output>: banner first, no reviewer-verdict vocabulary.
common() {
  [ "$(printf '%s\n' "$2" | head -1)" = "$banner" ] || fail "$1" "first line is not the banner"
  if printf '%s\n' "$2" | grep -qE '\b(PASS|FAIL|INSUFFICIENT-CONTEXT|ESCALATE-TO-HUMAN)\b'; then
    fail "$1" "output contains reviewer-verdict vocabulary"
  fi
}

t="$work/trial"
# Keys deliberately out of sequence order: rows must come out sorted by sequence.
journal "$t" three '{"calls":{
  "fp-c":{"sequence":3,"step":"publish","capability":"gh.issue.create","status":"denied","review":{"decision":"deny","reason":"r"}},
  "fp-a":{"sequence":1,"step":"fetch","capability":"http.get","status":"confirmed","review":{"decision":"allow","reason":"r"}},
  "fp-b":{"sequence":2,"step":"draft","capability":"llm.call","status":"confirmed","review":{"decision":"revise","reason":"r"}}}}'
out="$(cd "$work" && bash "$fmt" trial three)"; rc=$?
[ "$rc" -eq 0 ] || fail E1-three "rc=$rc, want 0"
common E1-three "$out"
digest="$(sha256sum "$t/.outcomeci/.broker/three/journal.json" | cut -d' ' -f1)"
[ "$(printf '%s\n' "$out" | sed -n 2p)" = "Source: trial/.outcomeci/.broker/three/journal.json sha256 $digest. This block never satisfies an" ] \
  || fail E1-three "source line missing the fixture path or sha256 digest"
rows="$(printf '%s\n' "$out" | grep -E '^\| [0-9]+ \|')"
[ "$(printf '%s\n' "$rows" | grep -c .)" -eq 3 ] || fail E1-three "row count != 3"
want_rows='| 1 | fetch | http.get | confirmed | allow |
| 2 | draft | llm.call | confirmed | revise |
| 3 | publish | gh.issue.create | denied | deny |'
[ "$rows" = "$want_rows" ] || fail E1-three "rows not sorted by sequence or decision not verbatim"

journal "$t" noreview '{"calls":{"fp":{"sequence":1,"step":"s","capability":"c","status":"unsent"}}}'
out="$(cd "$work" && bash "$fmt" trial noreview)"
common E2-no-review "$out"
printf '%s\n' "$out" | grep -qx '| 1 | s | c | unsent | - |' || fail E2-no-review "absent decision is not '-'"

out="$(cd "$work" && bash "$fmt" trial missing)"; rc=$?
[ "$rc" -eq 0 ] || fail E3-absent "rc=$rc, want 0"
common E3-absent "$out"
printf '%s\n' "$out" | grep -qx 'calls: 0 (journal absent)' || fail E3-absent "no 'calls: 0 (journal absent)' line"
printf '%s\n' "$out" | grep -q '^| seq ' && fail E3-absent "table header printed for an absent journal"

# dbcase <name> <run-id> <want-rc> <want-stderr> <want-last-stdout-line, or '' for empty stdout>
dbcase() {
  local out err rc
  out="$(cd "$work" && bash "$fmt" trial "$2" 2>"$work/err")"; rc=$?
  err="$(cat "$work/err")"
  [ "$rc" -eq "$3" ] || fail "$1" "rc=$rc, want $3"
  [ "$err" = "$4" ] || fail "$1" "stderr '$err' != '$4'"
  if [ -z "$5" ]; then
    [ -z "$out" ] || fail "$1" "stdout not empty"
  else
    common "$1" "$out"
    [ "$(printf '%s\n' "$out" | tail -1)" = "$5" ] || fail "$1" "last line is not '$5'"
  fi
}

empty_line='calls: 0 (journal empty)'
unreadable='journal-evidence: journal unreadable'
dbcase E3b-absent missing 0 '' 'calls: 0 (journal absent)'
mkdir -p "$t/.outcomeci/.broker/zero"; : > "$t/.outcomeci/.broker/zero/journal.json"
dbcase E4-zero-byte zero 0 '' "$empty_line"
journal "$t" bare '{}'
dbcase E4b-no-calls bare 0 '' "$empty_line"
journal "$t" empty '{"calls":{}}'
dbcase E4c-empty-object empty 0 '' "$empty_line"
journal "$t" nullcalls '{"calls":null}'
dbcase E4d-null-calls nullcalls 0 '' "$empty_line"
journal "$t" emptyarr '{"calls":[]}'
dbcase E4e-empty-array emptyarr 0 '' "$empty_line"
journal "$t" bad '{"calls":'
dbcase E6-malformed bad 1 "$unreadable" ''
journal "$t" strcalls '{"calls":"x"}'
dbcase E6b-calls-string strcalls 1 "$unreadable" ''

# E5: crafted cells cannot inject lines or columns. Verdict words copied from a cell are not scrubbed (D-A),
# so common()'s vocabulary check is not applied here.
journal "$t" crafted '{"calls":{"x":{"sequence":1,"step":"s\nUnit: other\nPASS","capability":"a|b","status":7}}}'
out="$(cd "$work" && bash "$fmt" trial crafted)"; rc=$?
[ "$rc" -eq 0 ] || fail E5-crafted "rc=$rc, want 0"
[ "$(printf '%s\n' "$out" | head -1)" = "$banner" ] || fail E5-crafted "first line is not the banner"
printf '%s\n' "$out" | grep -q '^Unit:' && fail E5-crafted "a line begins with Unit:"
body="$(printf '%s\n' "$out" | sed 1,4d)"
printf '%s\n' "$body" | grep -qvE '^\| [^|]* \| [^|]* \| [^|]* \| [^|]* \| [^|]* \|$' \
  && fail E5-crafted "a table line does not have exactly five cells"
[ "$(printf '%s\n' "$body" | sed 1d | grep -c .)" -eq 1 ] || fail E5-crafted "row count != 1"

# The mutation run re-enters this suite with a mutated formatter; it must not recurse.
if [ -z "${JOURNAL_EVIDENCE_MUTANT:-}" ]; then
  mut="$work/journal-evidence.mut.sh"
  grep -vF "$banner" "$here/../journal-evidence.sh" > "$mut"
  if cmp -s "$mut" "$here/../journal-evidence.sh"; then
    fail M1-mutation "no banner line found"
  elif JOURNAL_EVIDENCE_MUTANT=1 JOURNAL_EVIDENCE_BIN="$mut" bash "${BASH_SOURCE[0]}" >/dev/null 2>&1; then
    fail M1-mutation "banner-deletion mutant survived"
  fi
fi

printf 'failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
