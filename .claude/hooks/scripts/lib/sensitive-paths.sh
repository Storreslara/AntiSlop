# sensitive-paths.sh (st-u1): the reviewer-tier sensitive-path class, sourced by
# reviewer-tier.sh, unit-size.sh and review-precheck.sh so the three never drift.
# Sourced, never executed (mode 644). Defines SENSITIVE_PATHS and
# touches_sensitive_path <path> (exit 0 when the path is in the class).

# Size alone is unsafe: measured over the last 50 commits, three small diffs
# (1f 28L, 2f 41L, 1f 25L) were security/logic-critical. Size is therefore
# conjunctive with this path-class exclusion, which is never optional.
SENSITIVE_PATHS=(
  '^hooks/'
  '^\.claude/hooks/'
  '^adapters/.*hooks'
  '^bin/cli\.js$'
  '^tests/validate\.sh$'
  '^templates/persona-protocol.*\.md$'
  '^templates/settings-fragment\.json$'
  '^\.claude/settings.*\.json$'
  '^\.claude-plugin/'
  '^agents/'
  '^\.claude/agents/'
)

touches_sensitive_path() {
  local re
  for re in ${SENSITIVE_PATHS[@]+"${SENSITIVE_PATHS[@]}"}; do
    # `&& return 0` here would make a non-matching pattern the loop body's
    # exit status, which `set -e` treats as a script failure.
    if [[ "$1" =~ $re ]]; then
      return 0
    fi
  done
  return 1
}
