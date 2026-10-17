#!/usr/bin/env bash
# E2 fixture: template T1 (toy-lib) with cartTotal changed to round per line.
# Usage: build.sh DEST. Prints the baseline sha last.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
. "$ROOT/eval/abtest/fixtures/lib.sh"
dest="${1:?usage: build.sh DEST}"
mkdir -p "$dest"
cp -r "$ROOT/eval/fixtures/toy-lib-template/." "$dest/"
cp -r "$HERE/plant/." "$dest/"
# The template description names the eval and the claude CLI. This fixture replaces it, so
# neither arm can tell it is inside an eval; abt_fixture_baseline then scans the tree.
sed -i 's|^\(  "description": \).*$|\1"Minimal fixture library with no external dependencies.",|' "$dest/package.json"
grep -qF '"description": "Minimal fixture library with no external dependencies."' "$dest/package.json" || { echo "build: package.json description was not replaced" >&2; exit 1; }
abt_fixture_baseline "$dest"
