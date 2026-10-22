#!/usr/bin/env bash
# unit-size.sh (st-u4): the lane from a unit's planned scope. Cases (a) to (j) run in a temp repo;
# (k) reads the orchestrator prose (operator rulings OQ2 = ii, downgrade-only).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
US="$ROOT/bin/unit-size.sh"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$T" || exit 1
git init -q . && mkdir -p src test hooks docs/plans/p/contracts
export CLAUDE_PROJECT_DIR="$T"
BK="$T/.claude/bookkeeping"
is() { # <label> <want-line> <args...>
  local label="$1" want="$2"; shift 2
  local got; got="$(bash "$US" "$@")"
  [ "$got" = "$want" ] && ok "$label -> $want" || bad "$label: want '$want', got '$got'"
}

is "(a) two paths" 'lane: small files=2 reason=paths' u1 -- src/a.js test/a.test.js
[ "$(cat "$BK/u1.lane")" = 'lane: small files=2 reason=paths' ] && ok "(a) lane recorded" || bad "(a) lane record"
[ "$(cat "$BK/u1.scope")" = "$(printf 'src/a.js\ntest/a.test.js')" ] && ok "(a) scope recorded" || bad "(a) scope record"
is "(a) four is still small" 'lane: small files=4 reason=paths' u1 -- a b c d
is "(b) five is medium" 'lane: medium files=5 reason=paths' u1 -- a b c d e
is "(b) ten is medium" 'lane: medium files=10 reason=paths' u1 -- a b c d e f g h i j
is "(c) eleven is full" 'lane: full files=11 reason=size' u1 -- a b c d e f g h i j k
is "(d) a sensitive path" 'lane: full files=2 reason=sensitive' u1 -- src/a.js hooks/x.sh
is "(d) agents/ is sensitive" 'lane: full files=1 reason=sensitive' u1 -- agents/reviewer.md
mkdir -p "$T/.claude/reviewed" && printf 'FAIL u9 2026-10-20T00:00:00Z\ntier: sonnet\n- x\n' > "$T/.claude/reviewed/u9.fail"
is "(e) a FAIL record" 'lane: full files=1 reason=fail-record' u9 -- src/a.js
is "(f) a directory entry" 'lane: full files=1 reason=unmeasurable' u1 -- src
is "(f) a trailing slash" 'lane: full files=1 reason=unmeasurable' u1 -- lib/
is "(f) a glob" 'lane: full files=1 reason=unmeasurable' u1 -- 'src/*.js'
is "(f) a ./ entry the anchors cannot see" 'lane: full files=1 reason=unmeasurable' u1 -- ./hooks/x.sh
is "(f) a doubled slash" 'lane: full files=1 reason=unmeasurable' u1 -- src//a.js
is "(f) a leading slash" 'lane: full files=1 reason=unmeasurable' u1 -- /hooks/x.sh
cat > docs/plans/p/contracts/u2.md << 'MD'
Unit: u2

## Affected files
- `src/a.js`
- `test/a.test.js`
- `.claude/agents/reviewer.md`
- `docs/plans/p/spec.md`
MD
is "(g) contract, bookkeeping entries ignored" 'lane: small files=2 reason=contract' u2 --contract docs/plans/p/contracts/u2.md
is "(g) missing contract" 'lane: full files=0 reason=no-input' u2 --contract docs/plans/p/contracts/none.md
is "(g) no input" 'lane: full files=0 reason=no-input' u2
is "(h) only bookkeeping entries" 'lane: full files=0 reason=empty' u2 -- .claude/x docs/plans/y
bash "$US" '../x' -- a >/dev/null 2>&1; [ "$?" = 2 ] && [ ! -e "$T/.claude/x.lane" ] && ok "(i) bad unit id exit 2" || bad "(i) bad unit id"
mkdir -p "$T/lonely/bin" && cp "$US" "$T/lonely/bin/unit-size.sh"
[ "$(bash "$T/lonely/bin/unit-size.sh" u1 -- src/a.js)" = 'lane: full files=0 reason=unmeasurable' ] && ok "(j) library missing -> full" || bad "(j) library missing"
mkdir -p "$T/lonely/hooks/scripts/lib" && cp "$ROOT/hooks/scripts/lib/sensitive-paths.sh" "$T/lonely/hooks/scripts/lib/" && : > "$T/lonely/hooks/scripts/lib/unit-scope.sh"
[ "$(bash "$T/lonely/bin/unit-size.sh" u1 -- src/a.js)" = 'lane: full files=0 reason=unmeasurable' ] && ok "(j) library empty -> full" || bad "(j) library empty"

# (k) prose: the orchestrator routes on the lane, downgrade-only, medium lane without spec-master.
flat() { tr -s ' \n' ' ' < "$1"; }
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  for n in 'bash .claude/bin/unit-size.sh <task-id> --contract <contract file>' \
           'You may move a unit to a heavier lane than it prints, never to a lighter one.' \
           'A missing script, a non-zero exit or any other output is `full` too.' \
           'no spec-master and no explorer first' \
           'Write `## Affected files` and at most 5 numbered steps yourself' \
           'A request that needs more than 5 steps is `full`.' \
           'outside the small lane (see "Lane routing"), spawn `explorer` first' \
           '- Planning a non-trivial change in the full lane (see "Lane routing") → two-stage:'; do
    flat "$ROOT/$f" | grep -qF -- "$n" && ok "(k) $f: $n" || bad "(k) $f missing: $n"
  done
  flat "$ROOT/$f" | grep -qF 'Planning a non-trivial change → two-stage' && bad "(k) $f keeps the unrouted line" || ok "(k) $f: old routing line gone"
done
exit "$fail"
