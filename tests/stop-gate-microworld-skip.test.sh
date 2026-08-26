#!/usr/bin/env bash
# Unit B (spec2-unitB, docs/plans/2026-08-25-agent-throughput-performance-
# dampeners.md): stop-gate.sh step 4 skip precondition (microworld_skip_ok in
# hooks/scripts/lib/stop-gate-core.sh). Fixture-driven, invokes the real hook
# with canned SubagentStop payloads - no mocking. AC-B1 through AC-B6.
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/lib/timing-harness.sh
fail=0
tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

check() {
  # $1 = label, $2 = true|false, $3 = detail shown on failure
  if [ "$2" = true ]; then echo "OK   $1"; else echo "FAIL $1: $3"; fail=1; fi
}

# make_project <case> <check_cmd> -> a fresh git project, baseline-committed
# in one shot (gitignore + a "skiptest" bundle watching dirty.txt + config),
# so the ONLY thing a test case adds afterward is what it means to test as
# "changed since baseline". Mirrors this repo's own .gitignore for the paths
# stop-gate-core.sh/microworld-rerun touch, so re-running the hook never
# manufactures an unwatched "changed file" of its own (review-audit.log,
# the pending-review flag).
make_project() {
  local dir="$tmproot/$1" cmd="$2"
  mkdir -p "$dir/microworlds/skiptest" "$dir/.claude"
  printf 'microworlds/\n.claude/microworld-audit.log\n.claude/.pending-review.*\n.claude/review-audit.log\n.claude/.microworld-results-reported\n' \
    > "$dir/.gitignore"
  printf '{"watch": ["dirty.txt"]}\n' > "$dir/microworlds/skiptest/manifest.json"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"%s"}\n' "$cmd" \
    > "$dir/.claude/persona-config.json"
  git -C "$dir" init -q
  git -C "$dir" add -A
  git -C "$dir" -c user.email=t@t.test -c user.name=t commit -q -m init
  echo "$dir"
}

seed_dirty() { echo x > "$1/dirty.txt"; touch -d "$2" "$1/dirty.txt"; }
seed_pass() { printf '%s unit=skiptest result=pass file=dirty.txt\n' "$2" > "$1/.claude/microworld-audit.log"; }

run_stop() {
  # $1 = dir, $2 = entry script (default: the real stop-gate.sh)
  local entry="${2:-hooks/scripts/stop-gate.sh}" rc=0
  printf '%s' '{"hook_event_name":"SubagentStop","agent_type":"lead-programmer","session_id":"s","agent_id":"a1"}' \
    | CLAUDE_PROJECT_DIR="$1" bash "$entry" 2>"$tmproot/stderr.txt" || rc=$?
  return "$rc"
}

# --- AC-B1: skip works, gated SubagentStop completes p50<=2.0s p99<=5.0s ---
# (before: 102.56s stop-gate testAndLintCommand run). testAndLintCommand is
# something slow so a non-skip is a stark, unmissable budget blowout.
dir="$(make_project b1 'sleep 8')"
seed_dirty "$dir" '2026-08-25T00:00:00Z'
seed_pass "$dir" '2026-08-25T00:05:00Z'
export CLAUDE_PROJECT_DIR="$dir"
b1_rc=0
out="$(assert_budget "AC-B1 skip" 2.0 5.0 5 \
  '{"hook_event_name":"SubagentStop","agent_type":"lead-programmer","session_id":"s","agent_id":"a1"}' \
  -- bash hooks/scripts/stop-gate.sh)" || b1_rc=$?
echo "$out"
unset CLAUDE_PROJECT_DIR
check "AC-B1: gated SubagentStop completes within budget when the skip fires" \
  "$([ "$b1_rc" = 0 ] && echo true || echo false)" "$out"

# --- AC-B2: the skip is exit 0 and logs a distinct token -------------------
dir="$(make_project b2 false)"
seed_dirty "$dir" '2026-08-25T00:00:00Z'
seed_pass "$dir" '2026-08-25T00:05:00Z'
rc=0; run_stop "$dir" || rc=$?
n="$(grep -c 'microworld-skip=testAndLintCommand' "$dir/.claude/review-audit.log" 2>/dev/null || true)"
check "AC-B2: skip is exit 0 (testAndLintCommand=false never ran) and logs a distinct token" \
  "$([ "$rc" = 0 ] && [ "${n:-0}" = 1 ] && echo true || echo false)" "rc=$rc n=${n:-0}"

# --- AC-B3: mutation proof - a stale pass forces the full (failing) check --
dir="$(make_project b3 false)"
seed_dirty "$dir" '2026-08-25T00:10:00Z'
seed_pass "$dir" '2026-08-25T00:00:00Z'    # STALE: pass predates the edit
rc=0; run_stop "$dir" || rc=$?
check "AC-B3: a stale pass forces the full (failing) check to run and block" \
  "$([ "$rc" = 2 ] && echo true || echo false)" "rc=$rc"

mutant_lib="$tmproot/mutant-lib"
mkdir -p "$mutant_lib"
cp hooks/scripts/lib/stop-gate-core.sh "$mutant_lib/stop-gate-core.sh"
python3 - "$mutant_lib/stop-gate-core.sh" <<'PYEOF'
import sys
path = sys.argv[1]
old = '[[ "$ts" > "$file_iso" ]] || return 1'
new = 'true || return 1'
text = open(path).read()
assert text.count(old) == 1, f"expected exactly one occurrence, found {text.count(old)}"
open(path, "w").write(text.replace(old, new))
PYEOF
before_n=1
after_n="$(grep -cF '[[ "$ts" > "$file_iso" ]] || return 1' "$mutant_lib/stop-gate-core.sh" || true)"
parses=yes; bash -n "$mutant_lib/stop-gate-core.sh" 2>/dev/null || parses=no

mutant_entry="$tmproot/mutant-entry.sh"
cp hooks/scripts/stop-gate.sh "$mutant_entry"
mkdir -p "$tmproot/lib"
cp hooks/scripts/lib/agent-identity.sh "$tmproot/lib/agent-identity.sh"
python3 - "$mutant_entry" "$mutant_lib" <<'PYEOF'
import sys
path, mutant_lib = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
content = content.replace(
    'lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"\nsource "${lib_dir}/stop-gate-core.sh"',
    f'lib_dir="{mutant_lib}"\nsource "${{lib_dir}}/stop-gate-core.sh"'
)
with open(path, 'w') as f:
    f.write(content)
PYEOF

rc2=0; run_stop "$dir" "$mutant_entry" || rc2=$?
check "AC-B3 mutation proof: disabling the freshness check makes the stale-pass scenario wrongly ALLOW" \
  "$([ "${after_n:-1}" = 0 ] && [ "$parses" = yes ] && [ "$rc2" = 0 ] && echo true || echo false)" \
  "before=$before_n after=${after_n:-1} parses=$parses rc2=$rc2"

# --- AC-B4: the reviewer's independent run stays genuinely untouched -------
extract_clause() {
  awk '
    /^- \*\*Microworld bundles/{exit}
    /^- \*\*Run the checks yourself\*\*/{p=1}
    p{print}
  ' "$1"
}
cur_clause="$(extract_clause agents/reviewer.md)"
old_clause="$(git show 09cc304:agents/reviewer.md | extract_clause /dev/stdin)"
cur_hash="$(printf '%s' "$cur_clause" | sha256sum | cut -d' ' -f1)"
old_hash="$(printf '%s' "$old_clause" | sha256sum | cut -d' ' -f1)"
check "AC-B4a: reviewer.md's independent-verification clause is byte-identical to HEAD 09cc304" \
  "$([ -n "$cur_clause" ] && [ "$cur_hash" = "$old_hash" ] && echo true || echo false)" \
  "cur=$cur_hash old=$old_hash"

mw_block="$(sed -n '/# --- Unit B (cheapen the redundant stop-gate run): skip precondition/,/# --- end Unit B skip precondition/p' \
  hooks/scripts/lib/stop-gate-core.sh)"
reviewer_mentions="$(printf '%s' "$mw_block" | grep -ic 'reviewer' || true)"
check "AC-B4b: no Unit B code reads queue state on behalf of a reviewer identity (grep)" \
  "$([ "${reviewer_mentions:-0}" = 0 ] && echo true || echo false)" "mentions=${reviewer_mentions:-0}"

# --- AC-B5: fails closed --------------------------------------------------
dir="$(make_project b5-unwatched false)"
echo y > "$dir/other.txt"    # untracked, matched by no bundle's watch glob
seed_pass "$dir" '2026-08-25T00:05:00Z'
rc=0; run_stop "$dir" || rc=$?
check "AC-B5a: a changed file watched by no bundle forces the full (failing) check" \
  "$([ "$rc" = 2 ] && echo true || echo false)" "rc=$rc"

dir="$(make_project b5-noaudit false)"
seed_dirty "$dir" '2026-08-25T00:00:00Z'
rc=0; run_stop "$dir" || rc=$?   # no .claude/microworld-audit.log written at all
check "AC-B5b: a missing/unreadable audit log forces the full (failing) check" \
  "$([ "$rc" = 2 ] && echo true || echo false)" "rc=$rc"

dir="$(make_project b5-nonpass false)"
seed_dirty "$dir" '2026-08-25T00:00:00Z'
printf '2026-08-25T00:05:00Z unit=skiptest result=fail file=dirty.txt\n' > "$dir/.claude/microworld-audit.log"
rc=0; run_stop "$dir" || rc=$?
check "AC-B5c: a non-pass bundle result forces the full (failing) check" \
  "$([ "$rc" = 2 ] && echo true || echo false)" "rc=$rc"

# --- AC-B6: adapter parity is unaffected ------------------------------------
rc=0
bash tests/adapter-stop-gate-parity.test.sh > "$tmproot/parity-out.txt" 2>&1 || rc=$?
check "AC-B6: tests/adapter-stop-gate-parity.test.sh still passes unchanged" \
  "$([ "$rc" = 0 ] && echo true || echo false)" "rc=$rc (see $tmproot/parity-out.txt)"

exit "$fail"
