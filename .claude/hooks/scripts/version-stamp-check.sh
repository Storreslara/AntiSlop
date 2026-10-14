#!/usr/bin/env bash
# Flags a version-stamp-discipline violation (constitution P3): if a diff
# touches agents/*.md or anything under templates/, .claude-plugin/plugin.json's
# version must differ between the touching commit(s) and their own immediate
# parent(s) (see "per-commit semantics" below). Prints exactly
# `version-stamp-check: <ok|violation|unknown> touched: <yes|no|-> old: <ver|-> new: <ver|->`,
# exit 0 always. Usage: version-stamp-check.sh <commit-range>, e.g. baseline..HEAD,
# run from the repo root.
#
# Per-commit semantics: comparing plugin.json only at the range's two
# endpoints lets a later, unrelated version bump mask an earlier real
# violation when the caller reviews a range wider than the offending
# commit. To prevent that, every commit IN the range that itself touches
# agents/*.md or templates/* is checked against its own immediate parent;
# a violation in any one of them reports `violation` for the whole range,
# regardless of what the range's endpoints show. `old`/`new` in the output
# remain the range endpoints' versions (informational), not one commit's.
#
# CHANGELOG half: every touching commit that bumps the version must also add,
# in that same commit, a CHANGELOG.md line (a `+` line, not the `+++` header)
# naming, as a whole version (see changelog_adds_version), the version read from that commit's own
# .claude-plugin/plugin.json; a miss reports `violation` with the offender
# <short-sha>:CHANGELOG.md. The output format is unchanged.
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
# --no-color and --no-ext-diff keep a user's color.ui=always or diff.external
# from rewriting the lines this parses. python3 reads all of its input, so
# pipefail never sees a SIGPIPE from an early exit.
changelog_adds_version() {
  git diff --no-color --no-ext-diff --no-renames "$1^" "$1" -- CHANGELOG.md 2>/dev/null \
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

if [ "$touched" = no ]; then
  echo "version-stamp-check: ok touched: no old: - new: - offenders: -"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "version-stamp-check: unknown touched: yes old: - new: - offenders: -"
  exit 0
fi

old_ver="$(version_at "$old")"
new_ver="$(version_at "$new")"

# Check every commit in the range that itself touches a version-stamped
# path against its own immediate parent (see "per-commit semantics" above).
violation=no
unmeasurable=no
offenders=""
commits="$(git rev-list "$range" 2>/dev/null)" || commits=""
while IFS= read -r c; do
  [ -n "$c" ] || continue
  cfiles="$(git diff --no-renames --name-only "$c^" "$c" -- 2>/dev/null)" || continue
  c_touched=no
  cpaths=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
      agents/*.md|templates/*) c_touched=yes; cpaths="${cpaths:+$cpaths,}$f" ;;
    esac
  done <<< "$cfiles"
  [ "$c_touched" = yes ] || continue

  cold="$(version_at "$c^")"
  cnew="$(version_at "$c")"
  if [ -z "$cold" ] || [ -z "$cnew" ]; then
    unmeasurable=yes
  elif [ "$cold" = "$cnew" ]; then
    violation=yes
    short="${c:0:7}"
    IFS=',' read -ra cpath_arr <<< "$cpaths"
    for p in "${cpath_arr[@]}"; do
      [ -n "$p" ] || continue
      offenders="${offenders:+$offenders,}$short:$p"
    done
  elif [ "$cold" != "$cnew" ] && ! changelog_adds_version "$c" "$cnew"; then
    violation=yes
    short="${c:0:7}"
    offenders="${offenders:+$offenders,}$short:CHANGELOG.md"
  fi
done <<< "$commits"

if [ "$violation" = yes ]; then
  echo "version-stamp-check: violation touched: yes old: ${old_ver:--} new: ${new_ver:--} offenders: ${offenders:--}"
elif [ -z "$old_ver" ] || [ -z "$new_ver" ] || [ "$unmeasurable" = yes ]; then
  echo "version-stamp-check: unknown touched: yes old: ${old_ver:--} new: ${new_ver:--} offenders: -"
elif [ "$old_ver" = "$new_ver" ]; then
  echo "version-stamp-check: violation touched: yes old: $old_ver new: $new_ver offenders: ${offenders:--}"
else
  echo "version-stamp-check: ok touched: yes old: $old_ver new: $new_ver offenders: -"
fi
