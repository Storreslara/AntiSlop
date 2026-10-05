#!/usr/bin/env bash
# Exercises state-snapshot.sh and check-journal.sh against throwaway fixtures, plus a check-journal mutation case.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
snap="${SNAPSHOT_BIN:-$here/../state-snapshot.sh}"
chk="${CHECK_JOURNAL_BIN:-$here/../check-journal.sh}"
fmt="${JOURNAL_EVIDENCE_BIN:-$here/../journal-evidence.sh}"
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
  # LC_ALL=C: an unusable inherited locale makes bash itself warn on stderr, which is not the checker's output.
  [ -z "$(LC_ALL=C bash "$chk" "$t" zero 2>&1 >/dev/null)" ] || fail J9b-zero-byte-stderr "stderr not empty"
  journal "$t" arrstat '{"calls":{"a":{"status":["confirmed"]}}}'
  jcase J10-array-status nz 'journal=invalid calls=1 bad=1' "$t" arrstat
  mkdir -p "$t/.outcomeci/.broker/dir/journal.json"
  jcase J11-dir-journal nz 'journal=invalid calls=0 bad=0' "$t" dir --allow-absent
  mkdir -p "$t/.outcomeci/.broker/dangle"; ln -s "$work/no-such-file" "$t/.outcomeci/.broker/dangle/journal.json"
  jcase J12-dangling-symlink nz 'journal=invalid calls=0 bad=0' "$t" dangle --allow-absent
  bash "$fmt" "$t" dangle >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 1 ] || fail J12b-dangling-symlink-evidence "rc=$rc, want 1"
}

# runid_case <name> <script> <run-id>: exit 64, empty stdout, one stderr line naming the invalid run-id.
runid_case() {
  local out err rc
  out="$(LC_ALL=C bash "$2" "$work/trial" "$3" 2>"$work/err")"; rc=$?
  err="$(cat "$work/err")"
  [ "$rc" -eq 64 ] || fail "$1" "rc=$rc, want 64"
  [ -z "$out" ] || fail "$1" "stdout not empty"
  [ "$(printf '%s\n' "$err" | wc -l)" -eq 1 ] && [[ $err == *"invalid run-id"* ]] \
    || fail "$1" "stderr is not one 'invalid run-id' line: '$err'"
}

run_runid_cases() {
  local r i=0 rc
  for r in ../x a/b .. a..b ''; do
    i=$((i + 1))
    runid_case "R$i-check-journal" "$chk" "$r"
    runid_case "R$i-journal-evidence" "$fmt" "$r"
  done
  journal "$work/trial" run_01.a-b '{"calls":{}}'
  jcase R6-valid-check-journal 0 'journal=ok calls=0 bad=0' "$work/trial" run_01.a-b
  bash "$fmt" "$work/trial" run_01.a-b >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || fail R6-valid-journal-evidence "rc=$rc, want 0"
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
  run_snapshot_symlink_cases "$p"
}

# S6-S6c: symlinks are recorded as link:<sha256 of target string> lines and never followed.
# The spec's regex reads '\./?\.claude/'; '(\./)?' is its evident intent for the plain relpath format.
run_snapshot_symlink_cases() {
  local p="$1" a b n0 n1 h
  b="$(bash "$snap" "$p")"
  cp "$p/.claude/reviewed/u1.pass" "$work/u1.copy"
  rm "$p/.claude/reviewed/u1.pass"
  ln -s "$work/u1.copy" "$p/.claude/reviewed/u1.pass"
  a="$(bash "$snap" "$p")"
  [ "$a" != "$b" ] || fail S6-symlink "same-content symlink swap not detected"
  printf '%s\n' "$a" | grep -qE '^link:[0-9a-f]{64}  (\./)?\.claude/reviewed/' || fail S6-symlink "no link: line"
  n0="$(printf '%s\n' "$a" | tail -1 | cut -d= -f2)"
  ln -s "$work/no-such-file" "$p/.claude/reviewed/dangling.pass"
  n1="$(bash "$snap" "$p" | tail -1 | cut -d= -f2)"
  [ "$n1" -eq $((n0 + 1)) ] || fail S6b-dangling "snapshot-files $n0 -> $n1, want +1"
  printf 'outside content\n' > "$work/outside.txt"
  ln -s "$work/outside.txt" "$p/.claude/reviewed/out.pass"
  h="$(sha256sum < "$work/outside.txt" | cut -d' ' -f1)"
  a="$(bash "$snap" "$p")"
  if printf '%s\n' "$a" | grep -q "$h"; then fail S6c-no-follow "link target content hashed"; fi
  mkdir -p "$work/linkproj/.claude"
  ln -s "$p/.claude/reviewed" "$work/linkproj/.claude/reviewed"
  a="$(bash "$snap" "$work/linkproj")"
  printf '%s\n' "$a" | grep -qE '^link:[0-9a-f]{64}  \.claude/reviewed$' \
    || fail S6d-symlinked-start "a symlinked marker directory is not recorded as one link line"
}

run_journal_cases
run_runid_cases
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
