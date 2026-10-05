#!/usr/bin/env bash
# Exercises state-snapshot.sh and check-journal.sh against throwaway fixtures, plus a check-journal mutation case.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
snap="${SNAPSHOT_BIN:-$here/../state-snapshot.sh}"
chk="${CHECK_JOURNAL_BIN:-$here/../check-journal.sh}"
export PATH="$HOME/.local/bin:$PATH"
failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() { printf 'FAIL %s: %s\n' "$1" "$2"; failures=$((failures + 1)); }

# journal <trial-dir> <run-id> <json>
journal() {
  mkdir -p "$1/.outcomeci/.broker/$2"
  printf '%s\n' "$3" > "$1/.outcomeci/.broker/$2/journal.json"
}

# jcase <name> <want-rc: 0|nz> <want-line> <trial> <run> [flags...]
jcase() {
  local name="$1" want_rc="$2" want="$3" trial="$4" run="$5" out rc
  shift 5
  out="$(bash "$chk" "$@" "$trial" "$run" 2>/dev/null)"; rc=$?
  [ "$out" = "$want" ] || fail "$name" "line '$out' != '$want'"
  if [ "$want_rc" = 0 ] && [ "$rc" -ne 0 ]; then fail "$name" "rc=$rc, want 0"; fi
  if [ "$want_rc" = nz ] && [ "$rc" -eq 0 ]; then fail "$name" "rc=0, want non-zero"; fi
}

run_journal_cases() {
  local t="$work/trial"
  journal "$t" ok '{"calls":{"a":{"status":"confirmed"},"b":{"status":"denied","review":{"decision":"deny"}},"c":{"status":"unsent"},"d":{"status":"uncertain"}}}'
  jcase J1-valid 0 'journal=ok calls=4 bad=0' "$t" ok
  journal "$t" rev '{"calls":{"a":{"status":"confirmed"},"b":{"status":"reviewing"}}}'
  jcase J2-reviewing nz 'journal=invalid calls=2 bad=1' "$t" rev
  journal "$t" unk '{"calls":{"a":{"status":"bogus"}}}'
  jcase J3-unknown nz 'journal=invalid calls=1 bad=1' "$t" unk
  journal "$t" nostatus '{"calls":{"a":{}}}'
  jcase J3b-nostatus nz 'journal=invalid calls=1 bad=1' "$t" nostatus
  journal "$t" pend '{"calls":{"a":{"status":"pending"}}}'
  jcase J3c-pending nz 'journal=invalid calls=1 bad=1' "$t" pend
  journal "$t" bad '{"calls":'
  jcase J4-malformed nz 'journal=invalid calls=0 bad=0' "$t" bad
  journal "$t" arr '{"calls":[]}'
  jcase J4b-calls-not-object nz 'journal=invalid calls=0 bad=0' "$t" arr
  jcase J5-absent nz 'journal=absent calls=0 bad=0' "$t" nope
  jcase J6-absent-allowed 0 'journal=absent calls=0 bad=0' "$t" nope --allow-absent
  journal "$t" empty '{"calls":{}}'
  jcase J7-empty-calls 0 'journal=ok calls=0 bad=0' "$t" empty
  journal "$t" multi '{"calls":{}}
{"calls":{"a":{"status":"bogus"}}}'
  jcase J8-multi-doc nz 'journal=invalid calls=0 bad=0' "$t" multi
  mkdir -p "$t/.outcomeci/.broker/zero"; : > "$t/.outcomeci/.broker/zero/journal.json"
  jcase J9-zero-byte nz 'journal=invalid calls=0 bad=0' "$t" zero
  [ -z "$(bash "$chk" "$t" zero 2>&1 >/dev/null)" ] || fail J9b-zero-byte-stderr "stderr not empty"
  journal "$t" arrstat '{"calls":{"a":{"status":["confirmed"]}}}'
  jcase J10-array-status nz 'journal=invalid calls=1 bad=1' "$t" arrstat
  mkdir -p "$t/.outcomeci/.broker/dir/journal.json"
  jcase J11-dir-journal nz 'journal=invalid calls=0 bad=0' "$t" dir --allow-absent
}

run_snapshot_cases() {
  local p="$work/proj" a b before_status
  git init -q "$p"
  mkdir -p "$p/.claude/reviewed" "$p/.claude/human-review"
  printf 'PASS u1\n' > "$p/.claude/reviewed/u1.pass"
  printf 'h\n' > "$p/.claude/human-review/x.md"
  printf 'f\n' > "$p/.claude/.pending-review.a"
  printf 'j\n' > "$p/.claude/.review-join.u1"
  printf 'w\n' > "$p/.claude/wip-handoff.a"
  printf 'ignored\n' > "$p/.claude/other.txt"
  before_status="$(git -C "$p" status --porcelain)"
  a="$(bash "$snap" "$p")"; b="$(bash "$snap" "$p")"
  [ "$a" = "$b" ] || fail S1-stable "two snapshots differ"
  [ "$(printf '%s\n' "$a" | tail -1)" = 'snapshot-files=5' ] || fail S1b-count "last line '$(printf '%s\n' "$a" | tail -1)'"
  if printf '%s\n' "$a" | grep -q 'other.txt'; then fail S1c-scope "snapshot includes out-of-scope file"; fi
  [ "$(git -C "$p" status --porcelain)" = "$before_status" ] || fail S3-readonly "git status changed"
  printf 'PASS u2\n' > "$p/.claude/reviewed/u2.pass"
  b="$(bash "$snap" "$p")"
  [ "$a" != "$b" ] || fail S2-detects "new fixture file not detected"
  printf 'x\n' > "$p/.claude/reviewed/u2.pass"
  [ "$(bash "$snap" "$p")" != "$b" ] || fail S2b-detects-edit "content change not detected"
  printf 'B\n' > "$p/.claude/reviewed/B.pass"
  printf 'a\n' > "$p/.claude/reviewed/a.pass"
  a="$(bash "$snap" "$p" | sed '$d' | cut -d' ' -f3-)"
  [ "$a" = "$(printf '%s\n' "$a" | LC_ALL=C sort)" ] || fail S4-sorted "paths not LC_ALL=C sorted"
  mkdir -p "$work/noclaude"
  if bash "$snap" "$work/noclaude" >/dev/null 2>&1; then fail S5-no-claude "rc=0 with no .claude/"; fi
}

run_journal_cases
# The mutation run re-enters this suite with a mutated checker; it must not recurse.
if [ -z "${TRIAL_TOOLS_MUTANT:-}" ]; then
  run_snapshot_cases
  mut="$work/check-journal.mut.sh"
  sed 's/^.*# CHECK:STATUS$/bad_filter=0/' "$here/../check-journal.sh" > "$mut"
  if cmp -s "$mut" "$here/../check-journal.sh"; then
    fail M1-mutation "no CHECK:STATUS line found"
  elif TRIAL_TOOLS_MUTANT=1 CHECK_JOURNAL_BIN="$mut" bash "${BASH_SOURCE[0]}" >/dev/null 2>&1; then
    fail M1-mutation "status-set mutant survived"
  fi
fi

printf 'failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
