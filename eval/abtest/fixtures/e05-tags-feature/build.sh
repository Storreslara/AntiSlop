#!/usr/bin/env bash
# E5 fixture: template T2 (notes-svc) plus a v1 data dump and a README section
# that describes the v1 format. Usage: build.sh DEST. Prints the baseline sha last.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
. "$ROOT/eval/abtest/fixtures/lib.sh"
dest="${1:?usage: build.sh DEST}"
abt_dest_guard "$dest" || exit 2
mkdir -p "$dest"
cp -r "$ROOT/eval/abtest/templates/notes-svc/." "$dest/"
cp -r "$HERE/plant/data" "$dest/"
cat "$HERE/plant/README.fragment.md" >> "$dest/README.md"
abt_fixture_baseline "$dest"
