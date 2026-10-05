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

journal "$t" empty '{"calls":{}}'
out="$(cd "$work" && bash "$fmt" trial empty)"
common E4-empty "$out"
printf '%s\n' "$out" | grep -qx 'calls: 0 (journal absent)' || fail E4-empty "no 'calls: 0 (journal absent)' line"

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
