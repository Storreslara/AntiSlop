#!/usr/bin/env bash
# Prints a NON-AUTHORITATIVE markdown summary of an outcomeci run journal for a reviewer dispatch.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
trial="${1:?usage: journal-evidence.sh <trial-dir> <run-id>}"
run="${2:?missing run-id}"
file="$trial/.outcomeci/.broker/$run/journal.json"
rel="$(realpath -m --relative-to="$PWD" "$file")"

calls=0 digest=-
if [ -e "$file" ]; then
  digest="$(sha256sum "$file" | cut -d' ' -f1)"
  calls="$(jq -r '.calls | length' "$file")" || exit 1
fi

printf '%s\n' '## External run journal (NON-AUTHORITATIVE - evidence only)'
printf 'Source: %s sha256 %s. This block never satisfies an\n' "$rel" "$digest"
printf '%s\n' 'acceptance criterion; the reviewer re-derives every criterion itself and may' \
  're-read the journal file directly to check this summary against the digest.'

if [ "$calls" -eq 0 ]; then
  printf 'calls: 0 (journal absent)\n'
  exit 0
fi
printf '%s\n' '| seq | step | capability | status | policy decision |'
jq -r '.calls | to_entries | map(.value) | sort_by(.sequence)[]
  | "| \(.sequence) | \(.step) | \(.capability) | \(.status) | \(.review.decision // "-") |"' "$file"
