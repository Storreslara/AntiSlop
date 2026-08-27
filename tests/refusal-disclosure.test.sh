#!/usr/bin/env bash
# gh419/C5.1-C5.6: refusal-message disclosure hygiene for
# reviewed-path-gate.sh and human-decision-gate.sh. Asserts the eleven
# banned/required phrases from docs/plans/2026-08-25-harness-trust-gaps.md
# Step 5 against the gates' REAL runtime denial stderr only - never a
# tree-wide grep (D8: this plan doc and this file both name the banned
# phrases, so a tree-wide grep could never be satisfied by construction).
#
# Fixture hygiene: testAndLintCommand is "true", NEVER this repo's
# `bash tests/validate.sh` - this suite runs FROM validate.sh and would
# recurse.
set -euo pipefail
cd "$(dirname "$0")/.."
unset CLAUDE_PLUGIN_ROOT || true
fail=0

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

proj="$tmproot/proj"
mkdir -p "$proj/.claude/reviewed" "$proj/.claude/human-review/u1"
printf '%s\n' '{"gatedAgents":["lead-programmer"],"personaSelection":["reviewer"],"testAndLintCommand":"true"}' \
  > "$proj/.claude/persona-config.json"

marker=".claude/reviewed"
rpg_out="$tmproot/rpg.out"; rpg_err="$tmproot/rpg.err"
hdg_out="$tmproot/hdg.out"; hdg_err="$tmproot/hdg.err"
before="$tmproot/before.tree"; after="$tmproot/after.tree"

run_rpg() {
  rc=0
  : > "$rpg_out"; : > "$rpg_err"
  printf '%s' "$1" | CLAUDE_PROJECT_DIR="$proj" bash hooks/scripts/reviewed-path-gate.sh \
      >"$rpg_out" 2>"$rpg_err" || rc=$?
}

run_hdg() {
  rc=0
  : > "$hdg_out"; : > "$hdg_err"
  printf '%s' "$1" | CLAUDE_PROJECT_DIR="$proj" bash hooks/scripts/human-decision-gate.sh \
      >"$hdg_out" 2>"$hdg_err" || rc=$?
}

assert_absent() { # file label phrase
  local n; n="$(grep -cF -- "$3" "$1" 2>/dev/null || true)"
  [ "${n:-0}" = 0 ] && pass "$2 -> absent" || bad "$2 -> present ($n), expected 0"
}

assert_present() { # file label phrase
  local n; n="$(grep -cF -- "$3" "$1" 2>/dev/null || true)"
  [ "${n:-0}" -ge 1 ] && pass "$2 -> present ($n)" || bad "$2 -> absent, expected >=1"
}

# C5.4's "no new file is written" means the removed disclosure text does not
# reappear in some other channel - not that zero bytes touch disk. Both gates
# already append an identity line to review-audit.log on every denial
# (audit_append(), untouched by this unit), so a new file from that
# pre-existing logging is expected; what must NOT happen is any banned phrase
# turning up inside whatever new file(s) a denial creates.
assert_new_files_clean() { # label before after
  local label="$1" f leak=0
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    for phrase in 'OUT of the command text entirely' \
                  'quote-split, dot-segment, doubled-slash' \
                  'human-decision-gate.sh' 'never spells the path' \
                  'Splitting the path across shell variables' \
                  'reviewed-path-gate.sh' 'never spells DECISION'; do
      if grep -qF -- "$phrase" "$f"; then
        bad "$label new file $f carries removed disclosure text: $phrase"
        leak=1
      fi
    done
  done < <(comm -13 "$2" "$3")
  [ "$leak" = 0 ] && pass "$label new files carry no removed disclosure text (C5.4)"
}

# -- reviewed-path-gate.sh: Bash write into the marker dir, as lead-programmer --
find "$proj" -type f | sort > "$before"
run_rpg "$(jq -n --arg a "lead-programmer" --arg c "printf x > $marker/9.pass" \
    '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')"
find "$proj" -type f | sort > "$after"

[ "$rc" = 2 ] && pass "rpg denial exit code 2" || bad "rpg denial exit code -> $rc, expected 2"
[ ! -s "$rpg_out" ] && pass "rpg stdout empty on denial (C5.4)" || bad "rpg stdout non-empty on denial (C5.4)"
assert_new_files_clean "rpg" "$before" "$after"

assert_absent "$rpg_err" "rpg BANNED generalization"    'OUT of the command text entirely'
assert_absent "$rpg_err" "rpg BANNED enumeration"        'quote-split, dot-segment, doubled-slash'
assert_absent "$rpg_err" "rpg BANNED cross-reference"    'human-decision-gate.sh'
assert_absent "$rpg_err" "rpg BANNED rationale clause"   'never spells the path'
assert_present "$rpg_err" "rpg REQUIRED git commit -F route" 'git commit -F'
assert_present "$rpg_err" "rpg REQUIRED grep -r route"       'grep -r'
assert_present "$rpg_err" "rpg REQUIRED new prohibition sentence" \
  'self-authorized bypass whether or not this gate blocks it'

# -- human-decision-gate.sh: Write of DECISION, as reviewer (no grant exists) --
find "$proj" -type f | sort > "$before"
run_hdg "$(jq -n --arg a "antislop:reviewer" --arg p ".claude/human-review/u1/DECISION" \
    '{tool_name:"Write",agent_type:$a,tool_input:{file_path:$p}}')"
find "$proj" -type f | sort > "$after"

[ "$rc" = 2 ] && pass "hdg denial exit code 2" || bad "hdg denial exit code -> $rc, expected 2"
[ ! -s "$hdg_out" ] && pass "hdg stdout empty on denial (C5.4)" || bad "hdg stdout non-empty on denial (C5.4)"
assert_new_files_clean "hdg" "$before" "$after"

assert_absent "$hdg_err" "hdg BANNED named technique"    'Splitting the path across shell variables'
assert_absent "$hdg_err" "hdg BANNED cross-reference"    'reviewed-path-gate.sh'
assert_absent "$hdg_err" "hdg BANNED rationale clause"   'never spells DECISION'
assert_present "$hdg_err" "hdg REQUIRED marker template delimiter rule" 'the delimiter is single-quoted'
assert_present "$hdg_err" "hdg REQUIRED rm -rf discard route"           'rm -rf .claude/human-review/'
assert_present "$hdg_err" "hdg REQUIRED new prohibition sentence" \
  'self-authorized bypass whether or not this gate blocks it'

echo
if [ "$fail" = 0 ]; then
  echo "refusal-disclosure.test.sh: all checks passed"
else
  echo "refusal-disclosure.test.sh: FAILURES present"
fi
exit "$fail"
