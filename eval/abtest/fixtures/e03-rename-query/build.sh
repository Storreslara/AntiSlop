#!/usr/bin/env bash
# E3 fixture: template T2 (notes-svc) plus a shared test helper that calls
# store.query, used by two more test files. Usage: build.sh DEST.
# Prints the baseline sha last.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
. "$ROOT/eval/abtest/fixtures/lib.sh"
dest="${1:?usage: build.sh DEST}"
mkdir -p "$dest"
cp -r "$ROOT/eval/abtest/templates/notes-svc/." "$dest/"
cp -r "$HERE/plant/." "$dest/"
abt_fixture_baseline "$dest"
