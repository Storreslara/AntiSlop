#!/usr/bin/env bash
# Frozen-corpus test for the read-only families F1 and F3 of the benign-command lib
# (ptr-u7b-1). It sources the lib named by $BENIGN_LIB (default
# hooks/scripts/lib/benign-command.sh) and calls command_is_provably_benign
# directly for every line of the two corpus files, passing the command as an
# argument and never through eval. One line per case: ok|FAIL <positive|negative>
# <family|-> <cmd>. Exit 0 only when there is no FAIL line.
cd "$(dirname "$0")/.." || exit 1
lib="${BENIGN_LIB:-hooks/scripts/lib/benign-command.sh}"
# shellcheck source=/dev/null
. "$lib" || exit 1
dir=tests/fixtures/gate-fp-corpus
fail=0

while IFS= read -r line; do
  [ -n "$line" ] || continue
  fam="$(jq -r '.family' <<< "$line")"
  cmd="$(jq -r '.cmd' <<< "$line")"
  if command_is_provably_benign "$cmd"; then
    echo "ok positive $fam $cmd"
  else
    echo "FAIL positive $fam $cmd"
    fail=1
  fi
done < "$dir/positive.jsonl"

while IFS= read -r line; do
  [ -n "$line" ] || continue
  cmd="$(jq -r '.cmd' <<< "$line")"
  if command_is_provably_benign "$cmd"; then
    echo "FAIL negative - $cmd"
    fail=1
  else
    echo "ok negative - $cmd"
  fi
done < "$dir/negative.jsonl"

exit "$fail"
