#!/usr/bin/env bash
# Deterministic reviewer-tier selection: prints exactly `sonnet` or `opus` for
# one unit, exit 0. Usage: reviewer-tier.sh <task-id> <git-range>, run from the
# repo root.
#
# NOT A HOOK. This is an ORCHESTRATOR-INVOKED helper and is DELIBERATELY NOT
# registered in hooks/hooks.json - the missing registration is the design, not
# an omission to "fix"; registering it would wire an advisory helper into the
# live hook chain. It lives under hooks/scripts/ only so tests/validate.sh's
# bash-syntax sweep covers it automatically; its behaviour is covered by
# tests/reviewer-tier.test.sh, which validate.sh registers explicitly.
#
# Fail-closed by construction: anything unmeasurable, sensitive or oversized
# prints `opus`. The result is a NECESSARY condition for sonnet review, never a
# sufficient one - the orchestrator may downgrade sonnet->opus, never upgrade.
set -euo pipefail

MAX_CHANGED_LINES=40
MAX_CHANGED_FILES=3

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
)

opus() { echo opus; exit 0; }

touches_sensitive_path() {
  local re
  for re in "${SENSITIVE_PATHS[@]}"; do
    # `&& return 0` here would make a non-matching pattern the loop body's
    # exit status, which `set -e` treats as a script failure.
    if [[ "$1" =~ $re ]]; then
      return 0
    fi
  done
  return 1
}

task_id="${1:-}"
range="${2:-}"
project_dir="${CLAUDE_PROJECT_DIR:-.}"

# 1 - a durable FAIL record for this unit disqualifies it (same id sanitizing
# and same marker directory as task-gate.sh).
safe_id="${task_id//[^a-zA-Z0-9._-]/_}"
if [ -n "$safe_id" ] && [ -f "${project_dir}/.claude/reviewed/${safe_id}.fail" ]; then
  opus
fi

# 2 - an unmeasurable range. A leading dash would be read as a git option
# rather than a revision, so it is rejected before git ever sees it.
[ -n "$range" ] || opus
case "$range" in -*) opus ;; esac
# `--no-renames` keeps a moved file from being printed in compacted
# `{old => new}` form, and `core.quotepath=false` keeps a non-ASCII path from
# being C-quoted; either shape would slip a sensitive path past every anchor.
numstat="$(git -c core.quotepath=false diff --no-renames --numstat "$range" -- 2>/dev/null)" || opus

files=0
lines=0
while IFS=$'\t' read -r added deleted path; do
  [ -n "$path" ] || continue
  files=$((files + 1))
  # quotepath=false unquotes non-ASCII, but git still C-quotes a path holding a
  # quote or newline; such a path cannot be matched, so it is unmeasurable.
  case "$path" in '"'*) opus ;; esac
  # 3 - sensitive path class.
  if touches_sensitive_path "$path"; then
    opus
  fi
  # Binary files report `-` instead of a count, so their size is unmeasurable.
  case "${added}${deleted}" in *[!0-9]*) opus ;; esac
  lines=$((lines + added + deleted))
done <<< "$numstat"

# 4 - size, strictly greater-than: exactly 40 lines and exactly 3 files are
# both still eligible.
if [ "$files" -gt "$MAX_CHANGED_FILES" ]; then
  opus
fi
if [ "$lines" -gt "$MAX_CHANGED_LINES" ]; then
  opus
fi

echo sonnet
