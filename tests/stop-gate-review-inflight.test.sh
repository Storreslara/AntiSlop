#!/usr/bin/env bash
# Fixture-driven test: main-session Stop is allowed (read-only, no flag write)
# while a fresh, unsatisfied, non-advisory .review-join stamp covers the
# pending-review flags, and blocks in every other case.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
ago_iso() { date -u -d "@$(( $(date +%s) - $1 ))" +%Y-%m-%dT%H:%M:%SZ; }

make_project() {
  # $1 = case name, $2 = reviewGating mode (default enforce)
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  printf '{"agent":"orchestrator"}\n' > "$dir/.claude/settings.json"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true","reviewGating":{"mode":"%s"}}\n' \
    "${2:-enforce}" > "$dir/.claude/persona-config.json"
  echo "$dir"
}

run_stop() {
  local rc=0
  printf '%s' '{"hook_event_name":"Stop","stop_hook_active":false,"session_id":"s1"}' \
    | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

stamp_hash() { (cd "$1/.claude" && sha256sum .review-join.* 2>/dev/null | sort) || true; }

check() {
  if [ "$2" = pass ]; then echo "OK   $1"; else echo "FAIL $1"; fail=1; fi
}

flag() { printf '%s agent=x\n' "$(now_iso)" > "$1/.claude/.pending-review.x"; }
fresh() { printf '%s unit=u1 prior=none prior_mtime=-\n' "$(now_iso)" > "$1/.claude/.review-join.u1"; }

declare -A before after
# (a) fresh stamp + one flag -> allowed and logged
dir="$(make_project a)"; flag "$dir"; fresh "$dir"
before[a]="$(stamp_hash "$dir")"; rc="$(run_stop "$dir")"; after[a]="$(stamp_hash "$dir")"
if [ "$rc" = 0 ] && grep -q 'stop-allowed=review-in-flight units=u1' "$dir/.claude/review-audit.log" 2>/dev/null; then
  check "(a) fresh stamp lets Stop through, audit logged" pass
else check "(a) fresh stamp lets Stop through, audit logged (rc=$rc)" fail; fi

# (b) flag, no stamp -> blocked
dir="$(make_project b)"; flag "$dir"
before[b]="$(stamp_hash "$dir")"; rc="$(run_stop "$dir")"; after[b]="$(stamp_hash "$dir")"
if [ "$rc" = 2 ]; then check "(b) no stamp blocks" pass; else check "(b) no stamp blocks (rc=$rc)" fail; fi

# (c) stamp 1801 s old -> blocked
dir="$(make_project c)"; flag "$dir"
printf '%s unit=u1 prior=none prior_mtime=-\n' "$(ago_iso 1801)" > "$dir/.claude/.review-join.u1"
before[c]="$(stamp_hash "$dir")"; rc="$(run_stop "$dir")"; after[c]="$(stamp_hash "$dir")"
if [ "$rc" = 2 ]; then check "(c) stale stamp blocks" pass; else check "(c) stale stamp blocks (rc=$rc)" fail; fi

# (d) stamp already satisfied by a newer valid PASS -> blocked
dir="$(make_project d)"; flag "$dir"
printf '%s unit=u1 prior=fail prior_mtime=%s\n' "$(now_iso)" "$(( $(date +%s) - 100 ))" > "$dir/.claude/.review-join.u1"
printf 'PASS u1 %s commit: none criteria: x\n' "$(now_iso)" > "$dir/.claude/reviewed/u1.pass"
before[d]="$(stamp_hash "$dir")"; rc="$(run_stop "$dir")"; after[d]="$(stamp_hash "$dir")"
if [ "$rc" = 2 ]; then check "(d) satisfied stamp blocks" pass; else check "(d) satisfied stamp blocks (rc=$rc)" fail; fi

# (e) advisory stamp only -> blocked
dir="$(make_project e)"; flag "$dir"
printf '%s unit=u1 mode=advisory\n' "$(now_iso)" > "$dir/.claude/.review-join.u1.advisory"
before[e]="$(stamp_hash "$dir")"; rc="$(run_stop "$dir")"; after[e]="$(stamp_hash "$dir")"
if [ "$rc" = 2 ]; then check "(e) advisory stamp blocks" pass; else check "(e) advisory stamp blocks (rc=$rc)" fail; fi

# (f) two flags, one stamp -> blocked
dir="$(make_project f)"; flag "$dir"; fresh "$dir"
printf '%s agent=y\n' "$(now_iso)" > "$dir/.claude/.pending-review.y"
before[f]="$(stamp_hash "$dir")"; rc="$(run_stop "$dir")"; after[f]="$(stamp_hash "$dir")"
if [ "$rc" = 2 ]; then check "(f) more flags than stamps blocks" pass; else check "(f) more flags than stamps blocks (rc=$rc)" fail; fi

# (g) stamps untouched by cases a-f, and the hashes are non-vacuous
same=pass
for c in a b c d e f; do [ "${before[$c]}" = "${after[$c]}" ] || same=fail; done
[ -n "${before[a]}" ] || same=fail
check "(g) stamps byte-identical before/after (a)-(f)" "$same"

# (h) mode off -> allowed, audit log untouched
dir="$(make_project h off)"; flag "$dir"; fresh "$dir"; printf 'x\n' > "$dir/.claude/review-audit.log"
rc="$(run_stop "$dir")"; n="$(wc -l < "$dir/.claude/review-audit.log")"
if [ "$rc" = 0 ] && [ "$n" = 1 ]; then check "(h) mode off allows, audit log unchanged" pass
else check "(h) mode off allows, audit log unchanged (rc=$rc lines=$n)" fail; fi

# (i) malformed stamp (no unit=) -> blocked, file kept
dir="$(make_project i)"; flag "$dir"
printf '%s prior=none\n' "$(now_iso)" > "$dir/.claude/.review-join.u1"
rc="$(run_stop "$dir")"
if [ "$rc" = 2 ] && [ -f "$dir/.claude/.review-join.u1" ]; then check "(i) malformed stamp blocks and survives" pass
else check "(i) malformed stamp blocks and survives (rc=$rc)" fail; fi

# (j) empty-reason defer + fresh stamp -> blocked
dir="$(make_project j)"; fresh "$dir"; printf 'defer: \n' > "$dir/.claude/.pending-review.x"
rc="$(run_stop "$dir")"
if [ "$rc" = 2 ]; then check "(j) empty-reason defer not excused by a stamp" pass
else check "(j) empty-reason defer not excused (rc=$rc)" fail; fi

# (k) empty-reason defer beside an undeferred flag, two fresh stamps -> still blocked
dir="$(make_project k)"; fresh "$dir"; flag "$dir"
printf '%s unit=u2 prior=none prior_mtime=-\n' "$(now_iso)" > "$dir/.claude/.review-join.u2"
printf 'defer: \n' > "$dir/.claude/.pending-review.z"
rc="$(run_stop "$dir")"
if [ "$rc" = 2 ]; then check "(k) empty-reason flag never excused, even with spare stamps" pass
else check "(k) empty-reason flag never excused (rc=$rc)" fail; fi

# rp-u2: strict ISO-8601 stamps not in the future, the .blocked/.escalated skips, the date -j fallback,
# the block message's last sentence and the duplicate-audit-line check.
run_stop_err() {
  printf '%s' '{"hook_event_name":"Stop","stop_hook_active":false,"session_id":"s1"}' \
    | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/stop-gate.sh 2>&1 >/dev/null || true
}
# (l) future-dated stamp -> blocked
dir="$(make_project l)"; flag "$dir"
printf '2099-01-01T00:00:00Z unit=u1 prior=none prior_mtime=-\n' > "$dir/.claude/.review-join.u1"
rc="$(run_stop "$dir")"
if [ "$rc" = 2 ]; then check "(l) future-dated stamp blocks" pass; else check "(l) future-dated stamp blocks (rc=$rc)" fail; fi

# (m) non-ISO timestamp that GNU date accepts -> blocked
dir="$(make_project m)"; flag "$dir"
printf 'now unit=u1 prior=none prior_mtime=-\n' > "$dir/.claude/.review-join.u1"
rc="$(run_stop "$dir")"
if [ "$rc" = 2 ]; then check "(m) non-ISO stamp blocks" pass; else check "(m) non-ISO stamp blocks (rc=$rc)" fail; fi

# (n) fresh stamp whose unit has a .blocked marker -> blocked
dir="$(make_project n)"; flag "$dir"; fresh "$dir"; printf 'BLOCKED u1\n' > "$dir/.claude/reviewed/u1.blocked"
rc="$(run_stop "$dir")"
if [ "$rc" = 2 ]; then check "(n) .blocked unit is not in flight" pass; else check "(n) .blocked unit is not in flight (rc=$rc)" fail; fi

# (o) fresh stamp whose unit has an .escalated marker -> blocked
dir="$(make_project o)"; flag "$dir"; fresh "$dir"; printf 'ESCALATED u1\n' > "$dir/.claude/reviewed/u1.escalated"
rc="$(run_stop "$dir")"
if [ "$rc" = 2 ]; then check "(o) .escalated unit is not in flight" pass; else check "(o) .escalated unit is not in flight (rc=$rc)" fail; fi

# (p) a date with no -d (BSD) -> the date -j fallback parses the stamp, Stop allowed
real_date="$(command -v date)"
mkdir -p "$tmproot/bsd"
printf '#!/usr/bin/env bash\nfor a in "$@"; do [ "$a" = -d ] && exit 1; done\nif [ "${1:-}" = -j ]; then exec %s -u -d "$5" "$6"; fi\nexec %s "$@"\n' "$real_date" "$real_date" > "$tmproot/bsd/date"
chmod +x "$tmproot/bsd/date"
dir="$(make_project p)"; flag "$dir"; fresh "$dir"
rc=0
printf '%s' '{"hook_event_name":"Stop","stop_hook_active":false,"session_id":"s1"}' \
  | PATH="$tmproot/bsd:$PATH" CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ] && grep -q 'stop-allowed=review-in-flight units=u1' "$dir/.claude/review-audit.log" 2>/dev/null; then
  check "(p) date -j fallback parses the stamp" pass
else check "(p) date -j fallback parses the stamp (rc=$rc)" fail; fi

# (q) the block message ends with the review-in-flight sentence
dir="$(make_project q)"; flag "$dir"
err="$(run_stop_err "$dir")"
if printf '%s' "$err" | grep -qF 'A reviewer dispatched with a `Unit:` line lets Stop through for 1800 s on its own; no flag write is needed.'; then
  check "(q) block message names the review-in-flight allow" pass
else check "(q) block message names the review-in-flight allow" fail; fi

# (r) two allowed Stops in a row log the review-in-flight line once
dir="$(make_project r)"; flag "$dir"; fresh "$dir"
rc1="$(run_stop "$dir")"; rc2="$(run_stop "$dir")"
n="$(grep -c 'stop-allowed=review-in-flight units=u1' "$dir/.claude/review-audit.log" 2>/dev/null || true)"
if [ "$rc1" = 0 ] && [ "$rc2" = 0 ] && [ "$n" = 1 ]; then check "(r) repeated allow logs one audit line" pass
else check "(r) repeated allow logs one audit line (rc1=$rc1 rc2=$rc2 lines=$n)" fail; fi

exit "$fail"
