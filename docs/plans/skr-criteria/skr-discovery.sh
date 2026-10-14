#!/usr/bin/env bash
# Usage: skr-discovery.sh "<expected skills/ dirs>" "<expected .claude/skills/ dirs>"
# Each argument is a space-separated, sorted-or-not list of directory names.
# Checks: the live skill sets are exactly the expected ones; no SKILL.md sits
# deeper than skills/<name>/SKILL.md or .claude/skills/<name>/SKILL.md; no
# SKILL.md under docs/ is reachable from npm packaging (package.json "files"
# names no docs/ path). Exit 0 iff all hold.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
[ "$#" -eq 2 ] || { echo "usage: $0 \"<skills>\" \"<.claude/skills>\"" >&2; exit 2; }
bad=0
norm() { tr ' ' '\n' | grep -v '^$' | sort | tr '\n' ' '; }
have_s="$(find skills -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | norm)"
have_c="$(find .claude/skills -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | norm)"
want_s="$(echo "$1" | norm)"; want_c="$(echo "$2" | norm)"
[ "$have_s" = "$want_s" ] || { echo "skills/ is [$have_s], expected [$want_s]"; bad=1; }
[ "$have_c" = "$want_c" ] || { echo ".claude/skills/ is [$have_c], expected [$want_c]"; bad=1; }
deep="$(find skills .claude/skills -mindepth 3 -name SKILL.md)"
[ -z "$deep" ] || { echo "nested SKILL.md: $deep"; bad=1; }
if node -e 'const f=require("./package.json").files||[];process.exit(f.some(x=>/^docs(\/|$)/.test(x))?1:0)'; then :; else
  echo "package.json files ships docs/"; bad=1; fi
[ "$bad" -eq 0 ] && echo "skr-discovery: ok"
[ "$bad" -eq 0 ]
