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
a one-line JSDoc naming eval(q)|/** Searches without eval(q). */
an indented one-line JSDoc naming eval(q)|    /** Searches without eval(q). */
a block comment naming eval(q) that closes on a later line|/* We never call eval(q) here,\n * because it is unsafe.\n */
a multi-line JSDoc naming eval(q)|/**\n * Searches without eval(q).\n */
a trailing comment with no space before the slashes|module.exports.legacy3 = 3;// not eval(x)
a trailing comment after a single-quoted string|const a = 'x'; // not eval(x)
a trailing comment after a double-quoted string|const b = "y"; // not Function(x)
a block comment and a trailing comment on one line|/* a */ module.exports.legacy4 = 4; // not eval(x)
a double-quoted string naming eval(x)|const t = "eval(x) is unsafe";
a single-quoted string naming Function(x)|const t2 = 'never Function(x)';
a JSDoc with a doubled closing star|/** not eval(x) **/ module.exports.legacy5 = 5;
a url string and a trailing comment naming eval(x)|const u2 = "http://x"; // not eval(x)
a real call after a one-line JSDoc|/** doc */ eval(q);
a real call after a single-quoted string ending in two slashes|const s2 = 'a //'; eval(q);
a real call after a double-quoted string ending in two slashes|const s3 = "a //"; eval(q);
a real call after a template literal ending in two slashes|const s4 = `a //`; eval(q);
a real call after a string holding a block comment opener|const s5 = "/*"; eval(q);
a real call inside a template interpolation|const s6 = `${eval(q)}`;
a real call before a trailing comment|eval(q); // done
a real new Function call after a block comment|/* c */ const g = new Function(q);
a real call after a string holding an escaped quote and two slashes|const s7 = "a \\" //"; eval(q);
a real Function call in a block|if (q) { Function(q)(); }
VARIANTS
