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
is "(a) four is still small" 'lane: small files=4 reason=paths' u1 -- a.js b.js c.js d.js
is "(b) five is medium" 'lane: medium files=5 reason=paths' u1 -- a.js b.js c.js d.js e.js
is "(b) ten is medium" 'lane: medium files=10 reason=paths' u1 -- a.js b.js c.js d.js e.js f.js g.js h.js i.js j.js
is "(c) eleven is full" 'lane: full files=11 reason=size' u1 -- a.js b.js c.js d.js e.js f.js g.js h.js i.js j.js k.js
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
is "(f) a .. out of docs/plans" 'lane: full files=1 reason=unmeasurable' u1 -- docs/plans/../../hooks/x.sh src/a.js
is "(f) a .. out of .claude" 'lane: full files=1 reason=unmeasurable' u1 -- .claude/../hooks/x.sh src/a.js
is "(f) a deep .. out of docs/plans" 'lane: full files=1 reason=unmeasurable' u1 -- docs/plans/x/../../../hooks/x.sh src/a.js
is "(f) a .. entry alone" 'lane: full files=0 reason=unmeasurable' u1 -- docs/plans/../../hooks/x.sh
is "(f) a glob under .claude" 'lane: full files=1 reason=unmeasurable' u1 -- '.claude/*.json' src/a.js
cat > docs/plans/p/contracts/u3.md << 'MD'
Unit: u3

## Affected files
- `docs/plans/../../hooks/stop-gate.sh`
- `src/a.js`
MD
is "(f) contract, a .. out of docs/plans" 'lane: full files=1 reason=unmeasurable' u3 --contract docs/plans/p/contracts/u3.md
is "(l) a hand-edited .claude settings file" 'lane: full files=1 reason=sensitive' u1 -- .claude/settings.json src/a.js
is "(l) a .claude/hooks entry" 'lane: full files=1 reason=sensitive' u1 -- .claude/hooks/x.sh src/a.js
is "(l) a generated .claude/agents copy stays free" 'lane: small files=1 reason=paths' u1 -- .claude/agents/x.md src/a.js
is "(l) a generated .claude/bin copy stays free" 'lane: small files=1 reason=paths' u1 -- .claude/bin/x.sh src/a.js
is "(l) a docs/plans entry stays free" 'lane: small files=1 reason=paths' u1 -- docs/plans/p/spec.md src/a.js
is "(m) a dash argument" 'lane: full files=0 reason=unmeasurable' u1 -- -rf
is "(m) a dash argument among paths" 'lane: full files=0 reason=unmeasurable' u1 -- src/a.js -rf
is "(m) a newline in an argument" 'lane: full files=0 reason=unmeasurable' u1 -- $'src/a.js\nsrc/b.js'
# (n) st-u4 fix 2: one judge for every entry. A directory prefix is sensitive when the entry or the entry plus a
# slash is in the class (us_listed treats an entry as a directory prefix), and an existing directory outside the
# free zones is unmeasurable.
is "(n) a bare .claude/hooks dir" 'lane: full files=1 reason=sensitive' u1 -- .claude/hooks src/a.js
is "(n) a bare .claude/agents dir is not the free zone" 'lane: full files=1 reason=sensitive' u1 -- .claude/agents src/a.js
is "(n) a bare hooks dir" 'lane: full files=2 reason=sensitive' u1 -- hooks src/a.js
is "(n) a bare .claude dir" 'lane: full files=2 reason=sensitive' u1 -- .claude src/a.js
is "(n) a bare docs/plans dir" 'lane: full files=2 reason=unmeasurable' u1 -- docs/plans src/a.js
is "(n) a docs/plans subdirectory stays free" 'lane: small files=1 reason=paths' u1 -- docs/plans/p src/a.js
is "(n) a nested .claude/agents file stays free" 'lane: small files=1 reason=paths' u1 -- .claude/agents/x/y.md src/a.js
is "(n) a nested docs/plans file stays free" 'lane: small files=1 reason=paths' u1 -- docs/plans/a/b/c.md src/a.js
is "(n) an unmeasurable entry beats a sensitive one" 'lane: full files=2 reason=unmeasurable' u1 -- hooks/x.sh 'src/*.js'
. "$ROOT/hooks/scripts/lib/sensitive-paths.sh"
# One row per SENSITIVE_PATHS entry, in library order: the bare directory (or - when the pattern names a file)
# and a file form. Index 10 (.claude/agents/) is the free zone, asserted small below. A new pattern fails the
# count check until a row is added.
MX_DIR=(hooks .claude/hooks adapters/cursor/hooks - - - - - .claude-plugin agents -)
MX_FILE=(hooks/x.sh .claude/hooks/x.sh adapters/cursor/hooks/x.json bin/cli.js tests/validate.sh templates/persona-protocol.md templates/settings-fragment.json .claude/settings.json .claude-plugin/plugin.json agents/x.md .claude/agents/x.md)
[ "${#SENSITIVE_PATHS[@]}" = 11 ] && [ "${#MX_DIR[@]}" = 11 ] && [ "${#MX_FILE[@]}" = 11 ] && ok "(n) one matrix row per sensitive pattern" || bad "(n) the matrix has ${#MX_FILE[@]} rows for ${#SENSITIVE_PATHS[@]} patterns: add a row"
mx_full() { # <label> <form>: full in script mode, and in contract mode when us_entries keeps the token (it needs a / or a .)
  local got
  got="$(bash "$US" u1 -- "$2" src/a.js)"
  case "$got" in 'lane: full '*) ok "$1 script: $2 -> $got" ;; *) bad "$1 script: $2 -> '$got'" ;; esac
  case "$2" in *[/.]*)
    printf 'Unit: u4\n\n## Affected files\n- `%s`\n- `src/a.js`\n' "$2" > docs/plans/p/contracts/u4.md
    got="$(bash "$US" u4 --contract docs/plans/p/contracts/u4.md)"
    case "$got" in 'lane: full '*) ok "$1 contract: $2 -> $got" ;; *) bad "$1 contract: $2 -> '$got'" ;; esac ;;
  esac
}
for i in "${!SENSITIVE_PATHS[@]}"; do
  [ "$i" = 10 ] && continue
  [[ "${MX_FILE[$i]}" =~ ${SENSITIVE_PATHS[$i]} ]] && ok "(n) row $i file form is in the class" || bad "(n) row $i: ${MX_FILE[$i]} is not in ${SENSITIVE_PATHS[$i]}"
  mx_full "(n) row $i file" "${MX_FILE[$i]}"
  if [ "${MX_DIR[$i]}" != - ]; then
    [[ "${MX_DIR[$i]}/" =~ ${SENSITIVE_PATHS[$i]} ]] && ok "(n) row $i dir form is in the class" || bad "(n) row $i: ${MX_DIR[$i]}/ is not in ${SENSITIVE_PATHS[$i]}"
    mx_full "(n) row $i bare dir" "${MX_DIR[$i]}"
    mx_full "(n) row $i dir with slash" "${MX_DIR[$i]}/"
  fi
done
[[ "${MX_FILE[10]}" =~ ${SENSITIVE_PATHS[10]} ]] && ok "(n) row 10 is the exempt .claude/agents/ class" || bad "(n) row 10 is not .claude/agents/"
for f in "${MX_FILE[10]}" .claude/agents/sub/y.md .claude/bin/x.sh docs/plans/p/spec.md; do
  is "(n) free zone $f" 'lane: small files=1 reason=paths' u1 -- "$f" src/a.js
done
# (o) st-u4 fix 3: an entry is a directory prefix, so a directory that does not exist yet is judged by what could
# sit beneath it, never by the entry text alone. The first rows are the reproductions; the ancestor test closes the
# class for every pattern in the library.
ic() { # <label> <want-line> <entry>: the entry plus src/a.js, read from a contract
  printf 'Unit: u4\n\n## Affected files\n- `%s`\n- `src/a.js`\n' "$3" > docs/plans/p/contracts/u4.md
  is "$1" "$2" u4 --contract docs/plans/p/contracts/u4.md
}
is "(o) a new adapter dir" 'lane: full files=2 reason=sensitive' u1 -- adapters/windsurf src/a.js
is "(o) a new persona-protocol dir" 'lane: full files=2 reason=sensitive' u1 -- templates/persona-protocol-v2 src/a.js
is "(o) a new settings dir" 'lane: full files=1 reason=sensitive' u1 -- .claude/settings.d src/a.js
is "(o) a bare adapters dir" 'lane: full files=2 reason=sensitive' u1 -- adapters src/a.js
is "(o) a bare bin dir" 'lane: full files=2 reason=sensitive' u1 -- bin src/a.js
is "(o) a new module dir is a bigger task" 'lane: full files=2 reason=unmeasurable' u1 -- src/newmodule src/a.js
is "(o) a new file with an extension is one file" 'lane: small files=2 reason=paths' u1 -- src/new.js src/a.js
is "(o) a name that only starts like a file pattern is not sensitive" 'lane: small files=2 reason=paths' u1 -- bin/cli.jsx src/a.js
is "(o) a sibling of a file pattern is not sensitive" 'lane: small files=2 reason=paths' u1 -- tests/validate.sh.bak src/a.js
ic "(o) contract: a new adapter dir" 'lane: full files=2 reason=sensitive' adapters/windsurf
ic "(o) contract: a new persona-protocol dir" 'lane: full files=2 reason=sensitive' templates/persona-protocol-v2
ic "(o) contract: a new settings dir" 'lane: full files=1 reason=sensitive' .claude/settings.d
ic "(o) contract: a new module dir" 'lane: full files=2 reason=unmeasurable' src/newmodule
ic "(o) contract: an option-like entry" 'lane: full files=2 reason=unmeasurable' -hooks/x.sh
# One witness path per SENSITIVE_PATHS entry, in library order, each deeper than its pattern's head. Every proper
# ancestor of a witness, bare and with a slash, none of them on disk, must be full in script and contract mode.
# Index 10 (.claude/agents/) is the free zone: its ancestors .claude/agents/sub stay free, so only the two above it
# are asserted. A new pattern fails the count check until a witness is added.
WIT=(hooks/scripts/lib/x.sh .claude/hooks/scripts/x.sh adapters/windsurf/hooks/hooks.json bin/cli.js tests/validate.sh templates/persona-protocol-v2/x.md templates/settings-fragment.json .claude/settings.d/x.json .claude-plugin/sub/plugin.json agents/sub/x.md .claude/agents/sub/x.md)
[ "${#SENSITIVE_PATHS[@]}" = 11 ] && [ "${#WIT[@]}" = 11 ] && ok "(o) one witness per sensitive pattern" || bad "(o) ${#WIT[@]} witnesses for ${#SENSITIVE_PATHS[@]} patterns: add a witness"
for i in "${!SENSITIVE_PATHS[@]}"; do
  [[ "${WIT[$i]}" =~ ${SENSITIVE_PATHS[$i]} ]] && ok "(o) witness $i is in the class" || bad "(o) witness $i: ${WIT[$i]} is not in ${SENSITIVE_PATHS[$i]}"
  if [ "$i" = 10 ]; then
    for a in .claude/agents .claude; do mx_full "(o) witness 10 ancestor" "$a"; mx_full "(o) witness 10 ancestor" "$a/"; done
    continue
  fi
  a="${WIT[$i]}"
  while [[ "$a" == */* ]]; do
    a="${a%/*}"
    mx_full "(o) witness $i ancestor" "$a"
    mx_full "(o) witness $i ancestor" "$a/"
  done
done
mkdir -p adapters/keep && : > adapters/keep/README.md
is "(o) an existing file under an open-tail head stays small" 'lane: small files=2 reason=paths' u1 -- adapters/keep/README.md src/a.js
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
is "(h) only bookkeeping entries" 'lane: full files=0 reason=empty' u2 -- .claude/bin/x docs/plans/y
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
