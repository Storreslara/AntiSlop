#!/usr/bin/env bash
# Asserts every tests/<file> named in a tests/watch-map.json run[] command is
# registered (grep-able) in tests/validate.sh - a watch-map entry naming an
# unregistered suite must fail the merge gate, not rot silently.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

count="$(jq '.entries | length' tests/watch-map.json)"
if [ "$count" -eq 0 ]; then
  echo "FAIL tests/watch-map.json has no entries - this check would be vacuous"
  exit 1
fi

while IFS= read -r cmd; do
  token="$(echo "$cmd" | grep -oE 'tests/[A-Za-z0-9._-]+' | head -1)"
  if [ -z "$token" ]; then
    echo "FAIL could not extract a tests/<file> token from run command: $cmd"
    fail=1
    continue
  fi
  if grep -q -- "$token" tests/validate.sh; then
    echo "OK   $token (from \"$cmd\") is registered in tests/validate.sh"
  else
    echo "FAIL $token (from watch-map run command \"$cmd\") is not registered in tests/validate.sh"
    fail=1
  fi
done < <(jq -r '.entries[].run[]' tests/watch-map.json)

# Every microworlds/ bundle directory must be either registered in
# tests/watch-map.json's entries[] or recorded in its retired[] - an
# unregistered bundle silently drops out of the registry with no signal.
# microworlds/ is gitignored (ADR-0017) and absent in a fresh clone/CI
# checkout, so its absence is not itself a failure.
if [ ! -d microworlds ]; then
  echo "OK   microworlds/ directory absent - nothing to register"
else
  retired_missing_id="$(jq '[.retired[]? | select(has("id")|not)] | length' tests/watch-map.json)"
  if [ "$retired_missing_id" -ne 0 ]; then
    echo "FAIL tests/watch-map.json has a retired[] entry with no id field"
    fail=1
  fi

  entries_ids="$(jq -r '.entries[].id' tests/watch-map.json | sort)"
  retired_ids="$(jq -r '.retired[]?.id // empty' tests/watch-map.json | sort)"
  dup="$(comm -12 <(echo "$entries_ids") <(echo "$retired_ids"))"
  if [ -n "$dup" ]; then
    echo "FAIL the following id(s) appear in both entries[] and retired[] in tests/watch-map.json:"
    echo "$dup" | sed 's/^/     /'
    fail=1
  fi

  bundles="$(find microworlds -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)"
  known="$(printf '%s\n%s\n' "$entries_ids" "$retired_ids" | sort -u)"
  missing="$(comm -23 <(echo "$bundles") <(echo "$known"))"
  if [ -n "$missing" ]; then
    echo "FAIL the following microworlds/ bundle(s) are neither registered nor retired in tests/watch-map.json:"
    echo "$missing" | sed 's/^/     /'
    fail=1
  else
    echo "OK   every microworlds/ bundle directory is registered or retired in tests/watch-map.json"
  fi
fi

exit "$fail"
