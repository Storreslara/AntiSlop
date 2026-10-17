#!/usr/bin/env bash
# Shows that the E4 no-dynamic-evaluation-added check ignores comments that name eval or Function,
# whether the comment stands alone, trails code or sits inline, and still finds a real call after a
# comment: the reference solution plus one appended piece of text in src/server.js, one variant per line
# ("<label>: pass|fail"). Each variant starts from the reference commit.
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
i=0
while IFS='|' read -r label line; do
  i=$((i + 1))
  git -C "$T/w" reset -q --hard reference
  printf '%b\n' "$line" >> "$T/w/src/server.js"
  git -C "$T/w" add -A
  git -C "$T/w" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m "variant $i"
  json="$(bash "$ABT_REPO_ROOT/eval/abtest/checks/e04-search-injection/check.sh" "$T/w" "$base" "$base" "$HERE/allowed-paths.txt")"
  python3 -I -c 'import json,sys;c={x["id"]:x["pass"] for x in json.loads(sys.argv[1])};print("no-dynamic-evaluation-added with", sys.argv[2] + ":", "pass" if c["no-dynamic-evaluation-added"] else "fail")' "$json" "$label"
done <<'VARIANTS'
an own-line comment naming eval(x)|// never call eval(x) here
a trailing comment naming eval(x)|module.exports.legacy = 1; // not eval(x)
an inline block comment naming Function(x)|module.exports.legacy2 = 2; /* not Function(x) */
a call to evaluateRoute(q)|evaluateRoute(q);
a real call to eval(q)|eval(q);
a real call after a block comment|/* checked */ eval(q);
a real call between two block comments|/* a */ eval(q); /* b */
a real call after a block comment end|/*\n * note\n */ eval(q);
a real call after a string holding two slashes|const u = "http://x"; eval(u);
a real new Function call|const f = new Function(q);
VARIANTS
