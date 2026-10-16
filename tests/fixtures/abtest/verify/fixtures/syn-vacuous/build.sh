#!/usr/bin/env bash
set -euo pipefail
. "$ABT_REPO_ROOT/eval/abtest/fixtures/lib.sh"
mkdir -p "$1"
printf '1\n' > "$1/answer.txt"
printf '{"name":"syn","scripts":{"test":"true"}}\n' > "$1/package.json"
abt_fixture_baseline "$1"
