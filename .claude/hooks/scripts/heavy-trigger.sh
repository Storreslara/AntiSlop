#!/usr/bin/env bash
# Deterministic measured heavy-unit surface script: prints exactly
# `surface: <heavy|light|unknown> files: <n|-> lines: <n|->` for one git range,
# exit 0 always. Usage: heavy-trigger.sh <git-range>, run from the repo root.
#
# NOT A HOOK. This is a HELPER called by the reviewer at verdict time and is
# DELIBERATELY NOT registered in hooks/hooks.json - the missing registration
# is the design, not an omission to "fix"; registering it would wire a
# measurement helper into the live hook chain. It lives under hooks/scripts/
# only so tests/validate.sh's bash-syntax sweep covers it automatically; its
# behaviour is covered by tests/heavy-trigger.test.sh, which validate.sh
# registers explicitly.
#
# Measures ADR-0004 criterion 1 only: file count and line count. Deliberately
# does NOT measure criteria 2 (structural/cross-cutting) or 3
# (security-sensitive); see the ADR and Step 13 for the three-criterion rule.
set -euo pipefail

MIN_CHANGED_FILES=8
MIN_CHANGED_LINES=400

range="${1:-}"

# An unmeasurable range. A leading dash would be read as a git option rather
# than a revision, so it is rejected before git ever sees it.
if [ -z "$range" ]; then
  echo "surface: unknown files: - lines: -"
  exit 0
fi
case "$range" in -*) echo "surface: unknown files: - lines: -"; exit 0 ;; esac

# `--no-renames` keeps a moved file from being printed in compacted
# `{old => new}` form, and `core.quotepath=false` keeps a non-ASCII path from
# being C-quoted; either shape would slip past measurement. `diff.relative=false`
# is stronger than an anchoring concern: a repo config of `diff.relative=true`
# drops every path outside the cwd out of the numstat entirely.
numstat="$(git -c core.quotepath=false -c diff.relative=false diff --no-renames --numstat "$range" -- 2>/dev/null)" || {
  echo "surface: unknown files: - lines: -"
  exit 0
}

files=0
lines=0
while IFS=$'\t' read -r added deleted path; do
  [ -n "$path" ] || continue
  files=$((files + 1))
  # quotepath=false unquotes non-ASCII, but git still C-quotes a path holding a
  # quote or newline; such a path cannot be measured, so it is unmeasurable.
  case "$path" in '"'*)
    echo "surface: unknown files: - lines: -"
    exit 0
  ;; esac
  # Binary files report `-` instead of a count, so their size is unmeasurable.
  case "${added}${deleted}" in *[!0-9]*)
    echo "surface: unknown files: - lines: -"
    exit 0
  ;; esac
  lines=$((lines + added + deleted))
done <<< "$numstat"

# A range that resolves but measures nothing (no changed files) is unmeasurable.
if [ "$files" -eq 0 ]; then
  echo "surface: unknown files: - lines: -"
  exit 0
fi

# Criterion 1 measurement: heavy if files >= 8 OR lines >= 400
if [ "$files" -ge "$MIN_CHANGED_FILES" ] || [ "$lines" -ge "$MIN_CHANGED_LINES" ]; then
  echo "surface: heavy files: $files lines: $lines"
else
  echo "surface: light files: $files lines: $lines"
fi
exit 0
