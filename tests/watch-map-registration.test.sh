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

exit "$fail"
