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
# The template description names the eval and the claude CLI. This fixture
# replaces it, so neither arm can tell it is inside an eval.
sed -i 's|^\(  "description": \).*$|\1"Minimal fixture library with no external dependencies.",|' "$dest/package.json"
# Fail closed: the plant must have landed, and the tree must not name the eval.
need() { grep -qF -- "$2" "$dest/$1" 2> /dev/null || { echo "build: $1 lacks: $2" >&2; exit 1; }; }
need CONTEXT.md '**taxable amount**'
need CONTEXT.md 'never a fraction'
need CONTEXT.md 'never mutates its arguments'
need README.md 'all rates are percentages'
need package.json '"description": "Minimal fixture library with no external dependencies."'
need package.json '"test": "node --test"'
if grep -qiE 'antislop|eval|pilot|claude' "$dest/package.json" "$dest/README.md" "$dest/CONTEXT.md"; then
  echo "build: the built tree names the eval or the tool" >&2
  exit 1
fi
abt_fixture_baseline "$dest"
