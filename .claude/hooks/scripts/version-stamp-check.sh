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
# NOT A HOOK. This is a REVIEWER-INVOKED helper and is DELIBERATELY NOT
# registered in hooks/hooks.json, matching heavy-trigger.sh/reviewer-tier.sh:
# invoked deliberately against a specific unit's range, never self-derived.
# CI's shallow clone (fetch-depth: 1 in .github/workflows/validate.yml) makes
# a self-deriving HEAD~1-based check unreliable there; an explicit range
# supplied by the reviewer, who already has the unit's commits locally,
# sidesteps that entirely. It lives under hooks/scripts/ only so
# tests/validate.sh's bash-syntax sweep covers it automatically; its
# behaviour is covered by tests/version-stamp-check.test.sh, which
# validate.sh registers explicitly.
set -euo pipefail

unknown() { echo "version-stamp-check: unknown touched: - old: - new: -"; exit 0; }

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
  echo "version-stamp-check: ok touched: no old: - new: -"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "version-stamp-check: unknown touched: yes old: - new: -"
  exit 0
fi

old_ver="$(version_at "$old")"
new_ver="$(version_at "$new")"

# Check every commit in the range that itself touches a version-stamped
# path against its own immediate parent (see "per-commit semantics" above).
violation=no
unmeasurable=no
commits="$(git rev-list "$range" 2>/dev/null)" || commits=""
while IFS= read -r c; do
  [ -n "$c" ] || continue
  cfiles="$(git diff --no-renames --name-only "$c^" "$c" -- 2>/dev/null)" || continue
  c_touched=no
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
      agents/*.md|templates/*) c_touched=yes; break ;;
    esac
  done <<< "$cfiles"
  [ "$c_touched" = yes ] || continue

  cold="$(version_at "$c^")"
  cnew="$(version_at "$c")"
  if [ -z "$cold" ] || [ -z "$cnew" ]; then
    unmeasurable=yes
  elif [ "$cold" = "$cnew" ]; then
    violation=yes
  fi
done <<< "$commits"

if [ "$violation" = yes ]; then
  echo "version-stamp-check: violation touched: yes old: ${old_ver:--} new: ${new_ver:--}"
elif [ -z "$old_ver" ] || [ -z "$new_ver" ] || [ "$unmeasurable" = yes ]; then
  echo "version-stamp-check: unknown touched: yes old: ${old_ver:--} new: ${new_ver:--}"
elif [ "$old_ver" = "$new_ver" ]; then
  echo "version-stamp-check: violation touched: yes old: $old_ver new: $new_ver"
else
  echo "version-stamp-check: ok touched: yes old: $old_ver new: $new_ver"
fi
