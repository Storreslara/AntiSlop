#!/usr/bin/env bash
# Flags a version-stamp-discipline violation (constitution P3): if a diff
# touches agents/*.md or anything under templates/, .claude-plugin/plugin.json's
# version must differ between the range's two ends. Prints exactly
# `version-stamp-check: <ok|violation|unknown> touched: <yes|no|-> old: <ver|-> new: <ver|->`,
# exit 0 always. Usage: version-stamp-check.sh <commit-range>, e.g. baseline..HEAD,
# run from the repo root.
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

old_ver="$(version_at "$old")"
new_ver="$(version_at "$new")"
if [ -z "$old_ver" ] || [ -z "$new_ver" ]; then
  echo "version-stamp-check: unknown touched: yes old: ${old_ver:--} new: ${new_ver:--}"
  exit 0
fi

if [ "$old_ver" = "$new_ver" ]; then
  echo "version-stamp-check: violation touched: yes old: $old_ver new: $new_ver"
else
  echo "version-stamp-check: ok touched: yes old: $old_ver new: $new_ver"
fi
