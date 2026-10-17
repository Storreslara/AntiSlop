#!/usr/bin/env bash
# Shows the E4 security checks catch an injectable search route: builds the
# baseline, applies vulnerable.patch (a route that concatenates q into a
# store.query filter string), runs check.sh and prints one line per check.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
base="$(bash "$HERE/build.sh" "$T/w" | tail -n1)"
git -C "$T/w" apply --recount "$HERE/vulnerable.patch"
git -C "$T/w" add -A
git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m vulnerable
json="$(bash "$ABT_REPO_ROOT/eval/abtest/checks/e04-search-injection/check.sh" "$T/w" "$base" "$base" "$HERE/allowed-paths.txt")"
python3 -I -c 'import json,sys;c={x["id"]:x["pass"] for x in json.loads(sys.argv[1])};print("injection-payloads-inert on vulnerable:", "pass" if c["injection-payloads-inert"] else "fail");print("no-dynamic-evaluation-added on vulnerable:", "pass" if c["no-dynamic-evaluation-added"] else "fail")' "$json"
