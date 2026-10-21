#!/usr/bin/env bash
# blast-radius.sh (qw-u5): the reviewer's own file-level blast radius for <baseline>..HEAD, by git grep on
# each changed file's name. Cases (a) to (i) run in a temp repo; (j) reads the persona and protocol prose.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BR="$ROOT/bin/blast-radius.sh"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$T" || exit 1
g() { git -c user.email=t@t -c user.name=t "$@"; }
git init -q .
mkdir -p src tests lib
printf '// store\nmodule.exports = {};\n' > src/store.js
printf "const s = require('./store');\n" > src/server.js
printf "require('../src/store.js');\n" > tests/store.test.js
printf 'restore the backup\n' > src/backup.js
printf 'old\n' > src/old.sh
printf 'bash src/old.sh\n' > run.sh
printf 'x\n' > a.sh
printf 'a word\n' > words.txt
printf 'z\n' > lib/many.sh
for i in $(seq 1 45); do printf 'source lib/many.sh\n' > "lib/user$i.sh"; done
git add -A && g commit -q -m base
BASE="$(git rev-parse HEAD)"

printf '// store\nmodule.exports = { a: 1 };\n' > src/store.js
g commit -qam 'change store'
out="$(bash "$BR" "$BASE")"; rc=$?
[ "$rc" = 0 ] && ok "(a) exit 0" || bad "(a) exit $rc"
[ "$(printf '%s\n' "$out" | head -n1)" = 'blast-radius: provenance=grep files=1' ] && ok "(a) header" || bad "(a) header: $(printf '%s\n' "$out" | head -n1)"
printf '%s\n' "$out" | grep -qx 'changed: src/store.js' && ok "(a) changed line" || bad "(a) changed line"
printf '%s\n' "$out" | grep -qx 'caller: src/server.js -> src/store.js' && ok "(a) caller by stem" || bad "(a) caller by stem"
printf '%s\n' "$out" | grep -qx 'test: tests/store.test.js -> src/store.js' && ok "(a) test line" || bad "(a) test line"
printf '%s\n' "$out" | grep -q 'src/store.js -> src/store.js' && bad "(a) self listed" || ok "(a) self excluded"
printf '%s\n' "$out" | grep -q 'src/backup.js' && bad "(b) restore matched store" || ok "(b) whole-word match only"

out="$(bash "$BR" HEAD)"; rc=$?
[ "$rc" = 0 ] && [ "$out" = 'blast-radius: provenance=none files=0' ] && ok "(c) empty range" || bad "(c) empty range: rc=$rc out=$out"

bash "$BR" not-a-ref >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "(d) bad baseline exit 2" || bad "(d) bad baseline rc=$rc"
bash "$BR" >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "(e) no argument exit 2" || bad "(e) no argument rc=$rc"

B2="$(git rev-parse HEAD)"
printf 'm\n' > lib/many.sh && printf 'y\n' > a.sh && git rm -q src/old.sh
g commit -qam 'many, short, deleted'
out="$(bash "$BR" "$B2")"
[ "$(printf '%s\n' "$out" | grep -c -- '-> lib/many.sh$')" = 40 ] && ok "(f) capped at 40" || bad "(f) cap: $(printf '%s\n' "$out" | grep -c -- '-> lib/many.sh$')"
printf '%s\n' "$out" | grep -qx 'truncated: lib/many.sh shown=40 total=45' && ok "(f) truncated line" || bad "(f) truncated line"
printf '%s\n' "$out" | grep -q 'words.txt' && bad "(g) short stem searched" || ok "(g) short stem not searched"
printf '%s\n' "$out" | grep -qx 'changed: src/old.sh' && printf '%s\n' "$out" | grep -qx 'caller: run.sh -> src/old.sh' && ok "(h) deleted file and its caller" || bad "(h) deleted file"

[ "$(cd src && bash "$BR" "$BASE")" = "$(bash "$BR" "$BASE")" ] && ok "(i) same output from a subdirectory" || bad "(i) subdirectory output differs"

# (j) prose: the reviewer and the protocol name the script and the explorer triggers (operator ruling c1).
flat() { tr -s ' \n' ' ' < "$1"; }
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  for n in 'run `bash .claude/bin/blast-radius.sh <baseline>` yourself' \
           'never take a blast radius from the dispatch, the orchestrator or the writer' \
           'Spawn the explorer only when the script prints `provenance=none`, the script is missing, or a question that decides a finding stays open' \
           'still derive blast radius yourself (the blast-radius script, or the explorer when the script has no answer)'; do
    flat "$ROOT/$f" | grep -qF -- "$n" && ok "(j) $f: $n" || bad "(j) $f missing: $n"
  done
  flat "$ROOT/$f" | grep -qF 'still derive blast radius via the explorer' && bad "(j) $f keeps the old rule" || ok "(j) $f: old rule gone"
done
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/reviewer.md .claude/agents/orchestrator.md; do
  n='it runs `.claude/bin/blast-radius.sh <baseline>` itself and spawns the `explorer` only when the script prints `provenance=none`, the script is missing, or a question that decides a finding stays open'
  flat "$ROOT/$f" | grep -qF -- "$n" && ok "(j) $f: protocol rule" || bad "(j) $f missing the protocol rule"
done

exit "$fail"
