#!/usr/bin/env bash
# review-precheck.sh (st-u2): the reviewer's mechanical pre-review. Cases (a) to (i) run in a temp repo
# with a committed contract; (j) reads the reviewer and protocol prose.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PC="$ROOT/bin/review-precheck.sh"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$T" || exit 1
g() { git -c user.email=t@t -c user.name=t "$@"; }
git init -q . && mkdir -p src test docs/plans/p/contracts hooks
printf 'a\n' > src/a.js && printf 'ok\n' > test/a.test.sh
cat > docs/plans/p/contracts/u1.md << 'MD'
Unit: u1

## Affected files
- `src/a.js`
- `test/a.test.sh`

## Acceptance criteria
1. run: `bash -c 'grep -c b src/a.js'`
   exit: 0
   stdout: `1`
   mutation: none
2. run: `bash -c 'test -f src/a.js'`
   exit: 0
   stdout: empty
   mutation: none
3. run: `bash -c 'echo slow'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `slow`
   mutation: none
4. run: `bash -c 'echo hi'`
   exit: 0
   stdout: prints a greeting
   mutation: none
MD
cat > docs/plans/p/contracts/u2.md << 'MD'
Unit: u2

## Affected files
- `src/a.js`

## Do NOT touch
- `src/a.js` partial: past its first line
- `CONTEXT.md` (whole file; `src/a.js` is named here only as a reason)
MD
g add -A && g commit -q -m base && BASE="$(git rev-parse HEAD)"
C=docs/plans/p/contracts/u1.md
C2=docs/plans/p/contracts/u2.md
export CLAUDE_PROJECT_DIR="$T"
first() { printf '%s\n' "$1" | head -n1; }

printf 'a\nb\n' > src/a.js && g commit -qam 'u1: b'
out="$(bash "$PC" u1 "$BASE" --contract "$C")"; rc=$?
[ "$rc" = 0 ] && ok "(a) exit 0" || bad "(a) exit $rc"
[ "$(first "$out")" = "precheck: result=pass unit=u1 range=$BASE..$(git rev-parse HEAD) fails=0 deferred=1 judge=1" ] && ok "(a) header" || bad "(a) header: $(first "$out")"
for l in 'changed: src/a.js' 'scope: ok src/a.js listed' 'size: files=1 lines=1 binary=0' 'criterion 1: pass exit=0' 'criterion 2: pass exit=0' 'criterion 3: deferred long' 'criterion 4: judge stdout exit=0'; do
  printf '%s\n' "$out" | grep -qxF -- "$l" && ok "(a) $l" || bad "(a) missing: $l"
done
cmp -s <(printf '%s\n' "$out") "$T/.claude/bookkeeping/u1.precheck" && ok "(a) packet file equals stdout" || bad "(a) packet file differs"
bash "$PC" u2 "$BASE" --contract "$C2" | grep -qxF 'scope: ok src/a.js listed' && ok "(a) a partial: or reason-only Do NOT touch mention keeps a listed file" || bad "(a) listed file excluded by a partial bullet"

[ "$(bash "$PC" u1 "$BASE" --contract "$C" --criterion 3)" = 'criterion 3: pass exit=0' ] && ok "(b) --criterion runs a deferred one" || bad "(b) --criterion 3"

printf 'x\n' > CONTEXT.md && printf 'h\n' > hooks/g.sh && g add -A && g commit -q -m 'leak'
out="$(bash "$PC" u1 "$BASE" --contract "$C")"
printf '%s\n' "$out" | grep -qxF 'scope: out CONTEXT.md' && ok "(c) out-of-scope file" || bad "(c) out-of-scope file"
printf '%s\n' "$out" | grep -qxF 'sensitive: hooks/g.sh' && ok "(c) sensitive path" || bad "(c) sensitive path"
o2="$(bash "$PC" u2 "$BASE" --contract "$C2")"
printf '%s\n' "$o2" | grep -qxF 'scope: excluded CONTEXT.md' && ok "(c) a whole-file Do NOT touch bullet" || bad "(c) excluded class"
first "$o2" | grep -q '^precheck: result=fail .* fails=2 ' && ok "(c) an excluded file counts as a failure" || bad "(c) excluded not counted: $(first "$o2")"
first "$out" | grep -q '^precheck: result=fail .* fails=2 ' && ok "(c) result=fail fails=2" || bad "(c) header: $(first "$out")"
mkdir -p "$T/.claude/reviewed" && printf 'FAIL u1 2026-10-20T00:00:00Z\ntier: sonnet\n- CONTEXT.md:1 needs the term\n' > "$T/.claude/reviewed/u1.fail"
bash "$PC" u1 "$BASE" --contract "$C" | grep -qxF 'scope: ok CONTEXT.md fail-record' && ok "(c) path named by the .fail record" || bad "(c) fail-record class"
rm -rf "$T/.claude/reviewed"

g reset -q --hard HEAD~1
printf 'z\n' > src/a.js && g commit -qam 'u1: no b'
out="$(bash "$PC" u1 "$BASE" --contract "$C")"
printf '%s\n' "$out" | grep -qxF 'criterion 1: fail exit=1 want=0' && ok "(d) exit mismatch is a fail line" || bad "(d) exit mismatch"
printf 'b\nb\n' > src/a.js && g commit -qam 'u1: two b'
bash "$PC" u1 "$BASE" --contract "$C" | grep -q '^criterion 1: fail stdout want=1 got=2$' && ok "(d) stdout mismatch is a fail line" || bad "(d) stdout mismatch"

printf 'a\n' > src/a.js && sed -i 's/grep -c b/grep -c a/' "$C" && g commit -qam 'u1: weaken criterion'
out="$(bash "$PC" u1 "$BASE" --contract "$C")"
printf '%s\n' "$out" | grep -qxF "contract: changed-since-baseline $C" && ok "(e) contract edited after the baseline" || bad "(e) contract edit not flagged"
# The weakened criterion (grep -c a) passes on this tree and the baseline one (grep -c b) fails: only the baseline one may be graded.
printf '%s\n' "$out" | grep -qxF 'criterion 1: fail exit=1 want=0' && ok "(e) baseline criteria used" || bad "(e) criteria not from baseline"
TOP="$(git rev-parse --show-toplevel)"
out_abs="$(bash "$PC" u1 "$BASE" --contract "$TOP/$C")"; out_dots="$(bash "$PC" u1 "$BASE" --contract "docs/plans/p/../p/./contracts/u1.md")"
[ "$out_abs" = "$out" ] && ok "(e) an absolute --contract gives the same packet" || bad "(e) absolute spelling differs: $(first "$out_abs")"
[ "$out_dots" = "$out" ] && ok "(e) a .. and . --contract gives the same packet" || bad "(e) dots spelling differs: $(first "$out_dots")"
for bad_c in /etc/hostname ../x docs/../../x "$TOP/../x"; do
  bash "$PC" u1 "$BASE" --contract "$bad_c" >/dev/null 2>&1; [ "$?" = 2 ] && ok "(e) --contract outside the repository exit 2: $bad_c" || bad "(e) outside path accepted: $bad_c"
done
g reset -q --hard HEAD~1

# (e2) A contract the baseline does not have is a failure line and is never read from the working tree or HEAD.
C3=docs/plans/p/contracts/u3.md
cat > "$C3" << 'MD'
Unit: u3

## Affected files
- `src/a.js`

## Acceptance criteria
1. run: `bash -c 'echo 1'`
   exit: 0
   stdout: `1`
   mutation: none
MD
for stage in untracked committed-later; do
  [ "$stage" = committed-later ] && g add "$C3" && g commit -q -m 'contract after the baseline'
  out="$(bash "$PC" u3 "$BASE" --contract "$C3")"
  printf '%s\n' "$out" | grep -qxF "contract: not-at-baseline $C3" && ok "(e2) $stage: not-at-baseline line" || bad "(e2) $stage: no not-at-baseline line"
  first "$out" | grep -q '^precheck: result=fail .* fails=2 ' && ok "(e2) $stage: result=fail fails=2" || bad "(e2) $stage: $(first "$out")"
  printf '%s\n' "$out" | grep -q '^criterion [0-9]*: ' && bad "(e2) $stage: a criterion ran from an unpinned contract" || ok "(e2) $stage: no criterion ran"
  bash "$PC" u3 "$BASE" --contract "$C3" --criterion 1 >/dev/null 2>&1; [ "$?" = 2 ] && ok "(e2) $stage: --criterion exit 2" || bad "(e2) $stage: --criterion ran"
done
g reset -q --hard HEAD~1

# (e3) An uncommitted edit of the contract is not the unit's change: HEAD is compared, and criteria still come from the baseline.
sed -i 's/grep -c b/grep -c a/' "$C"
out="$(bash "$PC" u1 "$BASE" --contract "$C")"
printf '%s\n' "$out" | grep -q '^contract: ' && bad "(e3) an uncommitted contract edit was flagged" || ok "(e3) an uncommitted contract edit is not flagged"
printf '%s\n' "$out" | grep -q '^criterion 1: fail stdout want=1 got=2$' && ok "(e3) criteria still from the baseline" || bad "(e3) criteria from the working tree"
g checkout -q -- "$C"

out="$(bash "$PC" u1 "$BASE" --affected src/a.js)"
printf '%s\n' "$out" | grep -qxF 'scope: ok src/a.js listed' && ok "(f) --affected" || bad "(f) --affected"
printf '%s\n' "$out" | grep -qF 'criteria: none' && ok "(f) no contract, no criteria" || bad "(f) criteria line"
out="$(bash "$PC" u1 "$BASE")"
printf '%s\n' "$out" | grep -qxF 'scope: no-affected-list' && first "$out" | grep -q 'result=fail' && ok "(f) no list is a fail" || bad "(f) no list"
mkdir -p "$T/.claude/bookkeeping" && printf 'src/a.js\n' > "$T/.claude/bookkeeping/u1.scope"
bash "$PC" u1 "$BASE" | grep -qxF 'scope: ok src/a.js listed' && ok "(f) lane scope record used" || bad "(f) lane scope record"

printf '{"name":"x"}\n' > package.json && g add -A && g commit -q -m 'u1: pkg'
bash "$PC" u1 "$BASE" --contract "$C" | grep -qxF 'scope: judge package.json version-stamp-name' && ok "(g) version-stamp name left to the reviewer" || bad "(g) judge class"
mkdir -p .claude-plugin && printf '{}\n' > .claude-plugin/plugin.json && git add -A && g commit -q -m plugin-layout && B2="$(git rev-parse HEAD)"
printf '{"name":"y"}\n' > package.json && g commit -qam 'u1: bump'
bash "$PC" u1 "$B2" --contract "$C" | grep -qxF 'scope: ok package.json plugin-version' && ok "(g) plugin layout version file" || bad "(g) plugin-version class"

bash "$PC" '../x' "$BASE" >/dev/null 2>&1; [ "$?" = 2 ] && ok "(h) bad unit id exit 2" || bad "(h) bad unit id"
bash "$PC" u1 not-a-ref >/dev/null 2>&1; [ "$?" = 2 ] && ok "(h) bad baseline exit 2" || bad "(h) bad baseline"
bash "$PC" u1 "$BASE" --criterion 1 >/dev/null 2>&1; [ "$?" = 2 ] && ok "(h) --criterion without a contract exit 2" || bad "(h) --criterion without contract"
bash "$PC" u1 "$BASE" --bogus >/dev/null 2>&1; [ "$?" = 2 ] && ok "(h) unknown option exit 2" || bad "(h) unknown option"
[ "$(cd src && bash "$PC" u1 "$BASE" --contract "$C" | sed -n 2,99p)" = "$(bash "$PC" u1 "$BASE" --contract "$C" | sed -n 2,99p)" ] && ok "(i) same output from a subdirectory" || bad "(i) subdirectory differs"

# (m) a "`A` then `B`" stdout spec (tg-u1) is one expected stdout of several lines: the parts lose their
# backticks, are joined by newlines and compared exactly. Any other shape keeps its old reading.
C5=docs/plans/p/contracts/u5.md
cat > "$C5" << 'MD'
Unit: u5

## Acceptance criteria
1. run: `printf '0\nrc=0\n'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: none
2. run: `printf '0\nrc=1\n'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: none
3. run: `printf '1\n2\n3\n'`
   exit: 0
   stdout: `1` then `2` then `3`
   mutation: none
4. run: `echo 'a then b'`
   exit: 0
   stdout: `a then b`
   mutation: none
5. run: `printf '0\n1\n'`
   exit: 0
   stdout: `0` then `1` (two lines)
   mutation: none
6. run: `printf '0\n'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: none
7. run: `printf '0\nrc=0\nrc=1\n'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: none
8. run: `printf '0\nrc=0\n\n\n'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: none
9. run: `printf '0\nrc=0\n'`
   exit: 0
   stdout: `0`  then  `rc=0`
   mutation: none
10. run: `printf 'a\x60b\nrc=0\n'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: none
11. run: `printf '0\r\nrc=0\n'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: none
12. run: `printf '0\nrc=0'`
   exit: 0
   stdout: `0` then `rc=0`
   mutation: none
MD
g add "$C5" && g commit -q -m 'u5 contract' && B5="$(git rev-parse HEAD)"
m5() { bash "$PC" u5 "$B5" --contract "$C5" --criterion "$1"; }
[ "$(m5 1)" = 'criterion 1: pass exit=0' ] && ok "(m) two-part spec passes" || bad "(m) two-part: $(m5 1)"
[ "$(m5 2)" = 'criterion 2: fail stdout want=`0` then `rc=0` got=`0` then `rc=1`' ] && ok "(m) two-part mismatch fails, both sides shown" || bad "(m) mismatch: $(m5 2)"
[ "$(m5 3)" = 'criterion 3: pass exit=0' ] && ok "(m) three-part spec passes" || bad "(m) three-part: $(m5 3)"
[ "$(m5 4)" = 'criterion 4: pass exit=0' ] && ok "(m) a literal holding the word then is not split" || bad "(m) then-literal: $(m5 4)"
[ "$(m5 5)" = 'criterion 5: judge stdout exit=0' ] && ok "(m) text after the last part stays judge" || bad "(m) annotated: $(m5 5)"
[ "$(m5 6)" = 'criterion 6: fail stdout want=`0` then `rc=0` got=`0`' ] && ok "(m) a missing line fails" || bad "(m) short output: $(m5 6)"
[ "$(m5 7)" = 'criterion 7: fail stdout want=`0` then `rc=0` got=`0` then `rc=0` then `rc=1`' ] && ok "(m) an extra trailing line fails" || bad "(m) long output: $(m5 7)"
[ "$(m5 8)" = 'criterion 8: fail stdout want=`0` then `rc=0` got=`0` then `rc=0` then `` then ``' ] && ok "(m) extra trailing blank lines fail" || bad "(m) trailing blanks: $(m5 8)"
[ "$(m5 9)" = 'criterion 9: pass exit=0' ] && ok "(m) two spaces around then" || bad "(m) wide then: $(m5 9)"
[ "$(m5 10)" = 'criterion 10: fail stdout want=`0` then `rc=0` got=`a\`b` then `rc=0`' ] && ok "(m) a backtick in the output is escaped" || bad "(m) backtick: $(m5 10)"
[ "$(m5 11)" = 'criterion 11: fail stdout want=`0` then `rc=0` got=`0\r` then `rc=0`' ] && ok "(m) a CR in the output is shown as \\r" || bad "(m) CR: $(m5 11)"
[ "$(m5 12)" = 'criterion 12: pass exit=0' ] && ok "(m) no final newline still passes" || bad "(m) no final newline: $(m5 12)"
g reset -q --hard HEAD~1

# (k) a scope library that is missing or defines nothing: exit 2 and no packet (the reviewer runs the checks itself).
L="$(mktemp -d)"; mkdir -p "$L/bin" "$L/hooks/scripts/lib" && cp "$PC" "$L/bin/" && cp "$ROOT/hooks/scripts/lib/sensitive-paths.sh" "$L/hooks/scripts/lib/"
bash "$L/bin/review-precheck.sh" u1 "$BASE" --contract "$C" >/dev/null 2>&1; [ "$?" = 2 ] && ok "(k) unit-scope.sh missing: exit 2" || bad "(k) missing library"
: > "$L/hooks/scripts/lib/unit-scope.sh"
bash "$L/bin/review-precheck.sh" u1 "$BASE" --contract "$C" >/dev/null 2>&1; [ "$?" = 2 ] && ok "(k) unit-scope.sh empty: exit 2" || bad "(k) empty library"
rm -rf "$L"

# (l2-r1..r4) --blast-radius appends `br ` lines, or one `br blast-radius: unavailable` line.
P0="$(bash "$PC" u1 "$BASE" --contract "$C" 2>/dev/null)"; P1="$(bash "$PC" u1 "$BASE" --contract "$C" --blast-radius 2>/dev/null)"
grep -q '^br ' <<< "$P0" && bad "(l2-r1) br line without the flag" || ok "(l2-r1) no br line without the flag"
[ -n "$(grep '^br ' <<< "$P1")" ] && [ "$(grep -v '^br ' <<< "$P1")" = "$P0" ] && [ -z "$(sed -n '/^br /,$p' <<< "$P1" | grep -v '^br ')" ] \
  && ok "(l2-r2) flag only appends trailing br lines" || bad "(l2-r2) packet differs beyond br lines"
L="$(mktemp -d)"; mkdir -p "$L/bin" "$L/hooks/scripts/lib" && cp "$PC" "$L/bin/" && cp "$ROOT"/hooks/scripts/lib/*.sh "$L/hooks/scripts/lib/"
[ "$(bash "$L/bin/review-precheck.sh" u1 "$BASE" --contract "$C" --blast-radius 2>/dev/null | grep '^br ')" = "br blast-radius: unavailable" ] \
  && ok "(l2-r3) no blast-radius.sh: unavailable line" || bad "(l2-r3) unavailable line missing"
rm -rf "$L"
bash "$PC" u1 "$BASE" --contract "$C" --criterion 1 --blast-radius >/dev/null 2>&1; [ "$?" = 2 ] && ok "(l2-r4) --criterion with --blast-radius: exit 2" || bad "(l2-r4) not a usage error"

# (l2-sc) an Affected files token may end in :NN or :NN-NN and may hold one flat {a,b} group.
L2="$T/l2"; mkdir -p "$L2/src" && cd "$L2" && git init -q .
printf '## Affected files\n- `src/x.sh:48`\n- `src/{a,b}.sh`\n- `src/{c,{d,e}}.sh`\n\n## Acceptance criteria\n' > c.md
g add c.md && g commit -qm base && L2B="$(git rev-parse HEAD)"
for f in x a b c d e; do echo 1 > "src/$f.sh"; done
g add src && g commit -qm work
l2out="$(CLAUDE_PROJECT_DIR="$L2" bash "$PC" u "$L2B" --contract c.md)"
printf '%s\n' "$l2out" | grep -qxF 'scope: ok src/x.sh listed' && ok "(l2-sc1) :NN suffix is stripped" || bad "(l2-sc1) src/x.sh:48"
{ printf '%s\n' "$l2out" | grep -qxF 'scope: ok src/a.sh listed' && printf '%s\n' "$l2out" | grep -qxF 'scope: ok src/b.sh listed'; } && ok "(l2-sc2) {a,b} expands" || bad "(l2-sc2) brace group"
printf '%s\n' "$l2out" | grep -E '^scope: .* src/[cde]\.sh' | grep -qv 'scope: ok .* listed' && printf '%s\n' "$l2out" | grep -qE '^scope: out src/c\.sh' && ok "(l2-sc3) nested braces stay out" || bad "(l2-sc3) nested group: $(printf '%s\n' "$l2out" | grep 'src/c')"
cd "$T"

# (j) prose: the reviewer and the protocol name the pre-review script and its FAIL rule.
flat() { tr -s ' \n' ' ' < "$1"; }
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  for n in 'run `bash .claude/bin/review-precheck.sh <task-id> <baseline> --contract <contract path>` yourself' \
           'is a FAIL ground on its own: return FAIL quoting those lines, without reading the code' \
           'Do not re-run a criterion it reports `pass`; run each `deferred` one yourself with `--criterion <n>`' \
           '`scope: excluded`, `scope: no-affected-list`' \
           'or `contract: not-at-baseline` line is a FAIL ground on its own' \
           'The script reads the contract only from the baseline commit.' \
           'Read code only for judgment'; do
    flat "$ROOT/$f" | grep -qF -- "$n" && ok "(j) $f: $n" || bad "(j) $f missing: $n"
  done
done
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/reviewer.md .claude/agents/orchestrator.md; do
  n='It re-runs the checks with a script too: it runs `.claude/bin/review-precheck.sh` itself, treats each failure line as a FAIL ground, and re-runs by hand only what the script defers or cannot decide.'
  flat "$ROOT/$f" | grep -qF -- "$n" && ok "(j) $f: protocol rule" || bad "(j) $f missing the protocol rule"
done
exit "$fail"
