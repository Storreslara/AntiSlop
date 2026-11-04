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
# prints `opus`; a diff of only docs, fixtures and tests prints `sonnet` at any size.
# The result is a NECESSARY condition for sonnet review, never a
# sufficient one - the orchestrator may downgrade sonnet->opus, never upgrade.
set -euo pipefail
# A library that is missing, unreadable, empty or truncated leaves the FAIL-record
# check or the sensitive-path class unmeasurable, so it fails closed like every
# other unmeasurable input: opus, exit 0. Inside `if`, an undefined function is
# only "false" under `set -e`, so a sourced-but-empty lib would print sonnet.
# Both streams of the group are hidden: a library that prints when sourced would
# otherwise put a line in front of the result, and callers read the first line.
{ . "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh" \
  && . "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"; } >/dev/null 2>&1 || { echo opus; exit 0; }
declare -F touches_sensitive_path touches_low_risk_path unit_id_sanitize state_unit_marker_exists >/dev/null || { echo opus; exit 0; }

MAX_CHANGED_LINES=40
MAX_CHANGED_FILES=3

opus() { echo opus; exit 0; }

task_id="${1:-}"
range="${2:-}"

# The marker directory is resolved from the enclosing repo, not from the cwd:
# defaulting to `.` loses the record silently when this is invoked from a
# subdirectory, printing a normal `sonnet` while a live FAIL record exists.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  project_dir="$CLAUDE_PROJECT_DIR"
else
  project_dir="$(git rev-parse --show-toplevel 2>/dev/null)" || project_dir=.
fi
dot="${project_dir}/.claude"

# 1 - a durable FAIL record for this unit disqualifies it (same id sanitizing
# and same marker directory as task-gate.sh). Without an id there is no record
# to consult, so the disqualifier cannot be evaluated at all; with an id but no
# marker directory anywhere, it cannot be evaluated either - unmeasurable, so
# it fails closed like every other unmeasurable input.
[ -n "$task_id" ] || opus
safe_id="$(unit_id_sanitize "$task_id")"
[ -d "${dot}/reviewed" ] || opus
if state_unit_marker_exists "$safe_id" fail; then
  opus
fi

# 2 - an unmeasurable range. A leading dash would be read as a git option
# rather than a revision, so it is rejected before git ever sees it.
[ -n "$range" ] || opus
case "$range" in -*) opus ;; esac
# `--no-renames` keeps a moved file from being printed in compacted
# `{old => new}` form, and `core.quotepath=false` keeps a non-ASCII path from
# being C-quoted; either shape would slip a sensitive path past every anchor.
# `diff.relative=false` is stronger than an anchoring concern: a repo config of
# `diff.relative=true` drops every path outside the cwd out of the numstat
# entirely, so a sensitive file becomes invisible and the line count shrinks.
# The header's "run from the repo root" is advice, not enforcement.
numstat="$(git -c core.quotepath=false -c diff.relative=false diff --no-renames --numstat "$range" -- 2>/dev/null)" || opus

files=0
lines=0
low=0
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
  if touches_low_risk_path "$path"; then
    low=$((low + 1))
  fi
done <<< "$numstat"

# A range that resolves but measures nothing (no changed files) tells us
# nothing about the work under review, so it is unmeasurable too.
[ "$files" -gt 0 ] || opus

# 4 - every file low-risk (docs, fixtures, tests): sonnet at any size. Placed after
# every opus exit above, so it can only add a way to reach sonnet.
if [ "$low" -eq "$files" ]; then echo sonnet; exit 0; fi

# 5 - size, strictly greater-than: exactly 40 lines and exactly 3 files are
# both still eligible.
if [ "$files" -gt "$MAX_CHANGED_FILES" ]; then
  opus
fi
if [ "$lines" -gt "$MAX_CHANGED_LINES" ]; then
  opus
fi

echo sonnet
