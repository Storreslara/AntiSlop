#!/usr/bin/env bash
# Shows the E3 owner-isolation check catches a careless rename: the reference solution with
# the owner clause dropped from the title filter in src/server.js.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
base="$(bash "$HERE/build.sh" "$T/w" | tail -n1)"
git -C "$T/w" apply --recount "$HERE/reference.patch"
grep -qF 'n.owner === user && ' "$T/w/src/server.js" || { echo "careless-proof: the reference no longer has the owner clause to drop" >&2; exit 1; }
sed -i 's/n\.owner === user && //' "$T/w/src/server.js"
if grep -qF 'n.owner === user' "$T/w/src/server.js"; then echo "careless-proof: the owner clause is still there" >&2; exit 1; fi
git -C "$T/w" add -A
git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m careless
json="$(bash "$ABT_REPO_ROOT/eval/abtest/checks/e03-rename-query/check.sh" "$T/w" "$base" "$base" "$HERE/allowed-paths.txt")"
python3 -I -c 'import json,sys;c={x["id"]:x["pass"] for x in json.loads(sys.argv[1])};[print(k, "on careless rename:", "pass" if c[k] else "fail") for k in ("owner-isolation-preserved", "where-works", "behaviour-unchanged")]' "$json"
