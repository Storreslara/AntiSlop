#!/usr/bin/env bash
# Exercises oci-series-gate.sh (or $SERIES_GATE_BIN) against throwaway fixture
# repos and a stub oci; never touches the real project's marker state.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="${SERIES_GATE_BIN:-$here/../oci-series-gate.sh}"
id=ocig-fx
rv=reviewed
failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/stub"
cat > "$work/stub/oci" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_LOG"
exit "${STUB_RC:-0}"
EOF
chmod +x "$work/stub/oci"
log="$work/stub.log"

# new_fixture <name> <commit message>: a git repo with one commit; prints its path.
new_fixture() {
  local fx="$work/$1"
  git init -q "$fx"
  git -C "$fx" config user.email fx@example.invalid
  git -C "$fx" config user.name fx
  printf 'x\n' > "$fx/file"
  git -C "$fx" add file
  git -C "$fx" commit -q -m "$2"
  printf '%s\n' "$fx"
}

# write_marker <fixture> <unit> <first line>
write_marker() {
  mkdir -p "$1/.claude/$rv"
  printf '%s\n' "$3" > "$1/.claude/$rv/$2.pass"
}

pass_line() { # <unit> <sha> <criteria>
  printf 'PASS %s 2026-10-05T00:00:00Z commit: %s criteria: %s' "$1" "$2" "$3"
}

# run <fixture> <wrapper args...>: sets rc and err; stub log is reset first.
run() {
  local fx="$1"; shift
  rm -f "$log"
  STUB_LOG="$log" STUB_RC="${STUB_RC:-0}" PATH="$work/stub:$PATH" bash "$bin" --project-dir "$fx" "$@" \
    >/dev/null 2>"$work/err"
  rc=$?
  err="$(cat "$work/err")"
}

check() { # <case> <expected rc> [expected stderr]
  local ok=1
  [ "$rc" = "$2" ] || ok=0
  [ "$#" -lt 3 ] || [ "$err" = "$3" ] || ok=0
  if [ "$ok" -eq 1 ]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s: rc=%s (want %s) stderr=%s\n' "$1" "$rc" "$2" "$err"
    failures=$((failures + 1))
  fi
}

check_no_oci() { # <case>
  if [ -e "$log" ]; then
    printf 'FAIL %s: oci was invoked\n' "$1"
    failures=$((failures + 1))
  fi
}

refusal() { printf 'series-gate=refuse unit=%s reason=%s' "$1" "$2"; }

good="$(new_fixture good "feat($id): fixture commit (also ocig-t6)")"
good_sha="$(git -C "$good" rev-parse HEAD)"
write_marker "$good" "$id" "$(pass_line "$id" "$good_sha" true)"

# T1: no --unit
run "$good" -- workflow run wf.yaml
check T1 64 "$(refusal '' usage)"; check_no_oci T1

# T1b: no -- separator
run "$good" --unit "$id" workflow run wf.yaml
check T1b 64 "$(refusal "$id" usage)"; check_no_oci T1b

# T2: no marker
run "$good" --unit ocig-absent -- workflow run wf.yaml
check T2 65 "$(refusal ocig-absent marker-missing)"; check_no_oci T2

# T3: malformed line 1 (no timestamp)
write_marker "$good" ocig-t3 "PASS ocig-t3 commit: $good_sha criteria: true"
run "$good" --unit ocig-t3 -- workflow run wf.yaml
check T3 66 "$(refusal ocig-t3 marker-invalid)"; check_no_oci T3

# T3b: commit: none
write_marker "$good" ocig-t3b "$(pass_line ocig-t3b none true)"
run "$good" --unit ocig-t3b -- workflow run wf.yaml
check T3b 66 "$(refusal ocig-t3b marker-invalid)"; check_no_oci T3b

# T4: cited commit's message does not name the unit, and no candidate does
write_marker "$good" other-t4 "$(pass_line other-t4 "$good_sha" true)"
run "$good" --unit other-t4 -- workflow run wf.yaml
check T4 67 "$(refusal other-t4 commit-attribution)"; check_no_oci T4

# T5 / T5b: HEAD advanced one commit past the cited commit
adv="$(new_fixture adv "feat($id): fixture commit")"
adv_sha="$(git -C "$adv" rev-parse HEAD)"
write_marker "$adv" "$id" "$(pass_line "$id" "$adv_sha" true)"
git -C "$adv" commit -q --allow-empty -m "docs: later commit"
run "$adv" --unit "$id" -- workflow run wf.yaml
check T5 68 "$(refusal "$id" sha-mismatch)"; check_no_oci T5
run "$adv" --unit "$id" --sha "$adv_sha" -- workflow run wf.yaml
check T5b 0 "series-gate=allow unit=$id commit=$adv_sha"

# T6: criteria fail on re-run
write_marker "$good" ocig-t6 "$(pass_line ocig-t6 "$good_sha" false)"
run "$good" --unit ocig-t6 -- workflow run wf.yaml
check T6 69 "$(refusal ocig-t6 criteria-mismatch)"; check_no_oci T6

# T7: valid marker
run "$good" --unit "$id" -- workflow run wf.yaml
check T7 0 "series-gate=allow unit=$id commit=$good_sha"
if ! grep -q 'workflow run' "$log" 2>/dev/null; then
  printf 'FAIL T7: stub log lacks "workflow run"\n'
  failures=$((failures + 1))
fi

# T8: oci's exit code passes through
STUB_RC=7 run "$good" --unit "$id" -- workflow run wf.yaml
check T8 7

printf 'failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
