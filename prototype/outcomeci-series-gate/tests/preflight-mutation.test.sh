#!/usr/bin/env bash
# Applies each M1-M5 mutant to a temp copy of preflight.sh and checks preflight.test.sh kills it.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
suite="$here/preflight.test.sh"
orig="$here/../preflight.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The copy sits at the same depth as the real script so ../../hooks and ./workflow resolve.
mkdir -p "$work/prototype/outcomeci-series-gate"
ln -s "$root/hooks" "$work/hooks"
ln -s "$root/prototype/outcomeci-series-gate/workflow" "$work/prototype/outcomeci-series-gate/workflow"
copy="$work/prototype/outcomeci-series-gate/preflight.sh"

cp "$orig" "$copy"
if ! PREFLIGHT_BIN="$copy" bash "$suite" >/dev/null 2>&1; then
  printf 'baseline=fail\n'
  exit 1
fi

exprs=(
  's/|| have=1/|| :/'
  's/report tools "\$have" 2 /report tools "$have" 9 /'
  's/\[0-9a-f\]{7,40}/[^[:space:]]+/'
  's/rm -rf "\$tmp"/:/'
  's/--dir "\$tmp"/--dir "$here\/workflow"/'
)
mutants=0 killed=0
for i in "${!exprs[@]}"; do
  n=$((i + 1))
  sed "${exprs[$i]}" "$orig" > "$copy"
  if cmp -s "$copy" "$orig"; then
    printf 'M%s: nosite\n' "$n"
    continue
  fi
  mutants=$((mutants + 1))
  if PREFLIGHT_BIN="$copy" bash "$suite" >/dev/null 2>&1; then
    printf 'M%s: survived\n' "$n"
  else
    printf 'M%s: killed\n' "$n"
    killed=$((killed + 1))
  fi
done

printf 'mutants=%s killed=%s\n' "$mutants" "$killed"
[ "$mutants" -eq 5 ] && [ "$killed" -eq 5 ]
