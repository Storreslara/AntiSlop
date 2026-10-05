#!/usr/bin/env bash
# Disables each R2-R6 guard in a temp copy of the wrapper and checks the suite kills it.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
suite="$here/series-gate.test.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The copy sits at the same depth as the real wrapper so ../../hooks/scripts resolves.
mkdir -p "$work/prototype/outcomeci-series-gate"
ln -s "$root/hooks" "$work/hooks"
copy="$work/prototype/outcomeci-series-gate/oci-series-gate.sh"

cp "$here/../oci-series-gate.sh" "$copy"
if ! SERIES_GATE_BIN="$copy" bash "$suite" >/dev/null 2>&1; then
  printf 'baseline=fail (unmutated copy does not pass the suite)\n'
  exit 1
fi

mutants=0 killed=0
for n in 2 3 4 5 6; do
  sed "s/^.*# CHECK:R$n\$/:/" "$here/../oci-series-gate.sh" > "$copy"
  if cmp -s "$copy" "$here/../oci-series-gate.sh"; then
    printf 'R%s: no guard line found\n' "$n"
    continue
  fi
  mutants=$((mutants + 1))
  if SERIES_GATE_BIN="$copy" bash "$suite" >/dev/null 2>&1; then
    printf 'R%s: survived\n' "$n"
  else
    printf 'R%s: killed\n' "$n"
    killed=$((killed + 1))
  fi
done

printf 'mutants=%s killed=%s\n' "$mutants" "$killed"
[ "$killed" -eq "$mutants" ]
