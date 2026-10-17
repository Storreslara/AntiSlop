#!/usr/bin/env bash
# Shows the E3 old-api-gone check ignores a comment line that names the old API and still
# catches a real call: the reference solution plus one appended line in src/store.js.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABT_REPO_ROOT="${ABT_REPO_ROOT:-$(cd "$HERE/../../../.." && pwd)}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
base="$(bash "$HERE/build.sh" "$T/w" | tail -n1)"
git -C "$T/w" apply --recount "$HERE/reference.patch"
git -C "$T/w" add -A
git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m reference
git -C "$T/w" tag reference
stacked=0
i=0
while IFS='|' read -r label line; do
  i=$((i + 1))
  git -C "$T/w" reset -q --hard reference
  printf '%b\n' "$line" >> "$T/w/src/store.js"
  git -C "$T/w" add -A
  git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m "variant $i"
  [ "$(git -C "$T/w" rev-parse HEAD~1)" = "$(git -C "$T/w" rev-parse reference)" ] || stacked=$((stacked + 1))
  json="$(bash "$ABT_REPO_ROOT/eval/abtest/checks/e03-rename-query/check.sh" "$T/w" "$base" "$base" "$HERE/allowed-paths.txt")"
  python3 -I -c 'import json,sys;c={x["id"]:x["pass"] for x in json.loads(sys.argv[1])};print("old-api-gone with", sys.argv[2] + ":", "pass" if c["old-api-gone"] else "fail")' "$json" "$label"
done <<'VARIANTS'
a line comment naming query(filterString)|// replaces query(filterString)
a block comment naming query(x)|/*\n * query(x) is gone\n */
an unstarred block comment body naming query(x)|/*\nold: query(x)\n*/
a trailing comment naming query(x)|module.exports.legacy = 1; // was query(x)
a real call to store.query(x)|store.query(x);
a real call after a block comment on one line|/* legacy */ store.query(x);
a real call after a block comment end|/*\nlegacy\n*/ store.query(x);
a generator method named query|class Legacy {\n  *query(f) { return f; }\n}
a real call after a string holding two slashes|const u = "http://x"; store.query(u);
VARIANTS
echo "variants stacked on another variant: $stacked"
