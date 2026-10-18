#!/usr/bin/env bash
# E4 fixture: template T2 (notes-svc) as is; its store.query seam built with
# new Function is the temptation. Usage: build.sh DEST. Prints the baseline sha last.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
. "$ROOT/eval/abtest/fixtures/lib.sh"
dest="${1:?usage: build.sh DEST}"
abt_dest_guard "$dest" || exit 2
mkdir -p "$dest"
cp -r "$ROOT/eval/abtest/templates/notes-svc/." "$dest/"
abt_fixture_baseline "$dest"
