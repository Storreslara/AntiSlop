#!/usr/bin/env bash
# Flags a version-stamp-discipline violation (constitution P3), per release:
# a release is a commit that changes the `version` in .claude-plugin/plugin.json.
# Every commit in the range that is a release is checked for two things:
# (1) the same commit adds a CHANGELOG.md line (a `+` line, not the `+++`
# header) naming, as a whole version (see changelog_adds_version), its new
# version; a miss reports offender <short-sha>:CHANGELOG.md. (2) the new
# version is not lower than its parent's (numeric compare of dotted
# integers); a miss reports offender <short-sha>:.claude-plugin/plugin.json.
# A commit that touches agents/*.md or templates/* without a bump is ok.
# Prints exactly
# `version-stamp-check: <ok|violation|unknown> touched: <yes|no|-> old: <ver|-> new: <ver|-> offenders: <list|->`,
# exit 0 always. `touched` is informational: does any commit in the range touch
# agents/*.md or templates/*. `old`/`new` are the range endpoints' versions.
# Usage: version-stamp-check.sh <commit-range>, e.g. baseline..HEAD, run from
# the repo root.
#
# NOT A HOOK. This is a REVIEWER-INVOKED helper and is DELIBERATELY NOT
# registered in hooks/hooks.json, matching heavy-trigger.sh/reviewer-tier.sh:
# invoked deliberately against a specific unit's range, never self-derived.
# The range is a per-unit input only the reviewer knows: a self-derived HEAD~1
# sees only the last commit of a multi-commit unit. (Originally also motivated
# by CI's shallow clone; validate.yml has fetched full history since 192624f.)
# It lives under hooks/scripts/ only so tests/validate.sh's
# bash-syntax sweep covers it automatically; its behaviour is covered by
# tests/version-stamp-check.test.sh, which validate.sh registers explicitly.
set -euo pipefail

unknown() { echo "version-stamp-check: unknown touched: - old: - new: - offenders: -"; exit 0; }

range="${1:-}"
[ -n "$range" ] || unknown
case "$range" in -*) unknown ;; esac
case "$range" in *..*) ;; *) unknown ;; esac

old="${range%%..*}"
new="${range##*..}"
[ -n "$old" ] && [ -n "$new" ] || unknown

version_at() {
  local ref="$1" content
  content="$(git show "${ref}:.claude-plugin/plugin.json" 2>/dev/null)" || { printf ''; return; }
  printf '%s' "$content" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin)["version"])
except Exception:
    print("")
'
}

# changelog_adds_version <commit> <version>: succeeds iff <commit> adds a CHANGELOG.md
# line (a `+` line, not the +++ header) naming <version> as a whole version: the
# dots are literal, and the match may not continue into a digit on the right or
# into a digit or dot on the left, so 0.31.16 is not named by 0.31.166 or 10.31.16,
# while v0.31.16 and (0.31.16) are. The diff is taken against the first parent,
# like version_at "$c^", so a merge commit counts the lines its branch added.
# --no-color, --no-ext-diff and --no-textconv keep a user's color.ui=always,
# diff.external or .gitattributes textconv driver from rewriting the lines this
# parses. python3 reads all of its input, so pipefail never sees a SIGPIPE from
# an early exit.
changelog_adds_version() {
  git diff --no-color --no-ext-diff --no-textconv --no-renames "$1^" "$1" -- CHANGELOG.md 2>/dev/null \
    | python3 -c '
import re, sys
pat = re.compile(r"(?<![0-9.])" + re.escape(sys.argv[1]) + r"(?![0-9])")
lines = sys.stdin.read().splitlines()
sys.exit(0 if any(l.startswith("+") and not l.startswith("+++") and pat.search(l[1:]) for l in lines) else 1)
' "$2"
}

if ! files="$(git -c core.quotepath=false diff --no-renames --name-only "$range" -- 2>/dev/null)"; then
  unknown
fi

touched=no
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    agents/*.md|templates/*) touched=yes; break ;;
  esac
done <<< "$files"

if ! command -v python3 >/dev/null 2>&1; then
  echo "version-stamp-check: unknown touched: $touched old: - new: - offenders: -"
  exit 0
fi

# version_lower <old> <new>: succeeds iff <new> is numerically lower than <old>
version_lower() {
  python3 -c '
import sys
def key(v):
    return [int(x) for x in v.split(".")]
try:
    sys.exit(0 if key(sys.argv[2]) < key(sys.argv[1]) else 1)
except ValueError:
    sys.exit(1)
' "$1" "$2"
}

old_ver="$(version_at "$old")"
new_ver="$(version_at "$new")"

violation=no
unmeasurable=no
offenders=""
commits="$(git rev-list "$range" 2>/dev/null)" || commits=""
while IFS= read -r c; do
  [ -n "$c" ] || continue
  cold="$(version_at "$c^")"
  cnew="$(version_at "$c")"
  [ "$cold" != "$cnew" ] || continue
  short="${c:0:7}"
  if [ -z "$cold" ] || [ -z "$cnew" ]; then
    unmeasurable=yes
    continue
  fi
  if ! changelog_adds_version "$c" "$cnew"; then
    violation=yes
    offenders="${offenders:+$offenders,}$short:CHANGELOG.md"
  fi
  if version_lower "$cold" "$cnew"; then
    violation=yes
    offenders="${offenders:+$offenders,}$short:.claude-plugin/plugin.json"
  fi
done <<< "$commits"

if [ "$violation" = yes ]; then
  echo "version-stamp-check: violation touched: $touched old: ${old_ver:--} new: ${new_ver:--} offenders: ${offenders:--}"
elif [ -z "$old_ver" ] || [ -z "$new_ver" ] || [ "$unmeasurable" = yes ]; then
  echo "version-stamp-check: unknown touched: $touched old: ${old_ver:--} new: ${new_ver:--} offenders: -"
else
  echo "version-stamp-check: ok touched: $touched old: $old_ver new: $new_ver offenders: -"
fi
