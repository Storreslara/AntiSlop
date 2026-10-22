#!/usr/bin/env bash
# blast-radius.sh (qw-u5): file-level blast radius of <baseline>..HEAD for the reviewer, who runs it itself.
# For each changed file, git grep finds tracked files naming it (basename, and stem when 4+ chars).
# Read-only: never writes a file.
set -uo pipefail
[ "$#" -eq 1 ] || { echo "usage: blast-radius.sh <baseline>" >&2; exit 2; }
top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "blast-radius: not a git repository" >&2; exit 2; }
cd "$top" || exit 2
git rev-parse --verify -q "$1^{commit}" >/dev/null || { echo "blast-radius: baseline does not resolve: $1" >&2; exit 2; }
mapfile -t changed < <(git -c core.quotePath=false diff --name-only "$1..HEAD")
if [ "${#changed[@]}" -eq 0 ]; then echo "blast-radius: provenance=none files=0"; exit 0; fi
CAP=40
# rp-u7: at most MAXLINES lines after the header, then one `truncated: <n> more lines` line.
MAXLINES=300
# rp-u7: a test is a path under tests/ or __tests__/, or a .test/.spec (or _test/_spec) name with a code
# extension; docs/specs/ and *_spec.md are not tests.
TESTRE='(^|/)(tests|__tests__)/|[._-](test|spec)\.(sh|bash|js|cjs|mjs|jsx|ts|tsx|py|rb|go|rs)$'
# rp-u7: prints "<kind>: <path> -> <changed file>" per input line; no sed, so `|`, `&` and `\` in a path are kept.
emit() { local h; while IFS= read -r h; do if [ -n "$h" ]; then printf '%s: %s -> %s\n' "$1" "$h" "$2"; fi; done; }
body=""; failed=0
for p in "${changed[@]}"; do body+="changed: $p"$'\n'; done
for p in "${changed[@]}"; do
  b="${p##*/}"; s="${b%.*}"
  args=(-e "$b")
  if [ "$s" != "$b" ] && [ "${#s}" -ge 4 ]; then args+=(-e "$s"); fi
  hits="$(git -c core.quotePath=false grep -l -I -w -F "${args[@]}" -- . 2>/dev/null)"; rc=$?
  if [ "$rc" -gt 1 ]; then failed=1; continue; fi
  hits="$(printf '%s\n' "$hits" | grep -vxF -- "$p" | grep -v '^$' || true)"
  [ -n "$hits" ] || continue
  tests="$(printf '%s\n' "$hits" | grep -E -- "$TESTRE" || true)"
  callers="$(printf '%s\n' "$hits" | grep -vE -- "$TESTRE" || true)"
  lines="$(printf '%s\n' "$tests" | emit test "$p"; printf '%s\n' "$callers" | emit caller "$p")"
  total="$(printf '%s\n' "$lines" | wc -l | tr -d ' ')"
  body+="$(printf '%s\n' "$lines" | head -n "$CAP")"$'\n'
  if [ "$total" -gt "$CAP" ]; then body+="truncated: $p shown=$CAP total=$total"$'\n'; fi
done
if [ "$failed" = 1 ]; then echo "blast-radius: provenance=none files=${#changed[@]}"; else echo "blast-radius: provenance=grep files=${#changed[@]}"; fi
n="$(printf '%s' "$body" | wc -l | tr -d ' ')"
printf '%s' "$body" | sed -n "1,${MAXLINES}p"
if [ "$n" -gt "$MAXLINES" ]; then echo "truncated: $((n - MAXLINES)) more lines"; fi
exit 0
