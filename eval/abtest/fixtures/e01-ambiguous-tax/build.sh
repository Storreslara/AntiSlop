#!/usr/bin/env bash
# E1 fixture: template T1 (toy-lib) plus a glossary and a README that settle the
# task's ambiguities. Usage: build.sh DEST. Prints the baseline sha last.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
. "$ROOT/eval/abtest/fixtures/lib.sh"
dest="${1:?usage: build.sh DEST}"
mkdir -p "$dest"
cp -r "$ROOT/eval/fixtures/toy-lib-template/." "$dest/"
cp -r "$HERE/plant/." "$dest/"
abt_fixture_baseline "$dest"
