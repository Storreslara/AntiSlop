#!/usr/bin/env bash
# Prints a NON-AUTHORITATIVE markdown summary of an outcomeci run journal for a reviewer dispatch.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
trial="${1:?usage: journal-evidence.sh <trial-dir> <run-id>}"
run="${2?missing run-id}"
[[ $run =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ && $run != *..* ]] || { echo 'journal-evidence: invalid run-id' >&2; exit 64; }
file="$trial/.outcomeci/.broker/$run/journal.json"
rel="$(realpath -m --relative-to="$PWD" "$file")"
unreadable() { echo 'journal-evidence: journal unreadable' >&2; exit 1; }

# One row per call; every copied cell is a string with control characters and | replaced by a space (D-A).
rows_filter='def cell: tostring | gsub("[\\x00-\\x1f\\x7f|]"; " ");
  if length == 0 then empty
  elif length == 1 and (.[0] | type) == "object" and (.[0].calls | type | IN("object", "array", "null")) then
    .[0].calls // [] | [.[]] | sort_by(.sequence)[]
    | "| \(.sequence | cell) | \(.step | cell) | \(.capability | cell) | \(.status | cell) | \(.review.decision // "-" | cell) |"
  else error("unreadable") end'

state=absent digest=- rows=""
if [ -e "$file" ] || [ -L "$file" ]; then
  [ -f "$file" ] || unreadable
  rows="$(jq -rs "$rows_filter" "$file" 2>/dev/null)" || unreadable
  digest="$(sha256sum "$file" | cut -d' ' -f1)"
  state=empty
fi

printf '%s\n' '## External run journal (NON-AUTHORITATIVE - evidence only)'
printf 'Source: %s sha256 %s. This block never satisfies an\n' "$rel" "$digest"
printf '%s\n' 'acceptance criterion; the reviewer re-derives every criterion itself and may' \
  're-read the journal file directly to check this summary against the digest.'

if [ -z "$rows" ]; then
  printf 'calls: 0 (journal %s)\n' "$state"
  exit 0
fi
printf '%s\n' '| seq | step | capability | status | policy decision |' "$rows"
