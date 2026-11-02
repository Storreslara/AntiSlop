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

# rp-u7 (k) to (n): test paths, paths sed would break, non-ASCII paths, the total output cap.
mkdir -p docs/specs .claude/agent-memory/a __tests__ users
for f in widget.js 'a|b&c.sh' 'café.sh'; do printf 'w\n' > "src/$f"; done
printf 'see src/widget.js\n' > docs/specs/widget.md
printf 'see widget.js\n' > .claude/agent-memory/a/widget_spec.md
printf "require('../src/widget.js');\n" > __tests__/w.js
printf "require('./widget.js');\n" > src/widget.spec.ts
printf 'bash src/a|b&c.sh\nbash src/café.sh\n' > run2.sh
for i in 1 2 3 4 5 6 7 8; do printf 'z\n' > "lib/m$i.sh"; done
for i in $(seq 1 45); do printf 'source lib/m1.sh lib/m2.sh lib/m3.sh lib/m4.sh lib/m5.sh lib/m6.sh lib/m7.sh lib/m8.sh\n' > "users/u$i.sh"; done
git add -A && g commit -q -m 'rp-u7 fixtures'
B3="$(git rev-parse HEAD)"
for f in widget.js 'a|b&c.sh' 'café.sh'; do printf 'w2\n' > "src/$f"; done
g commit -qam 'change three'
out="$(bash "$BR" "$B3")"
printf '%s\n' "$out" | grep -qxF 'caller: docs/specs/widget.md -> src/widget.js' && ok "(k) docs/specs/ is not a test" || bad "(k) docs/specs/ is not a test"
printf '%s\n' "$out" | grep -qxF 'caller: .claude/agent-memory/a/widget_spec.md -> src/widget.js' && ok "(k) *_spec.md is not a test" || bad "(k) *_spec.md is not a test"
printf '%s\n' "$out" | grep -qxF 'test: __tests__/w.js -> src/widget.js' && ok "(k) __tests__/ is a test" || bad "(k) __tests__/ is a test"
printf '%s\n' "$out" | grep -qxF 'test: src/widget.spec.ts -> src/widget.js' && ok "(k) .spec.ts is a test" || bad "(k) .spec.ts is a test"
printf '%s\n' "$out" | grep -qxF 'caller: run2.sh -> src/a|b&c.sh' && ok "(l) | and & kept in the path" || bad "(l) | and & kept in the path"
printf '%s\n' "$out" | grep -qxF 'changed: src/café.sh' && printf '%s\n' "$out" | grep -qxF 'caller: run2.sh -> src/café.sh' && ok "(m) non-ASCII path unquoted" || bad "(m) non-ASCII path unquoted"
B4="$(git rev-parse HEAD)"
for i in 1 2 3 4 5 6 7 8; do printf 'm\n' > "lib/m$i.sh"; done
g commit -qam 'change eight'
out="$(bash "$BR" "$B4")"
[ "$(printf '%s\n' "$out" | head -n1)" = 'blast-radius: provenance=grep files=8' ] && ok "(n) header kept under the cap" || bad "(n) header: $(printf '%s\n' "$out" | head -n1)"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 302 ] && ok "(n) 300 lines after the header plus the marker" || bad "(n) line count: $(printf '%s\n' "$out" | wc -l)"
[ "$(printf '%s\n' "$out" | tail -n1)" = 'truncated: 36 more lines' ] && ok "(n) total truncated line" || bad "(n) last line: $(printf '%s\n' "$out" | tail -n1)"

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
  n='it runs `bash .claude/bin/blast-radius.sh <baseline>` itself and spawns the `explorer` only when the script prints `provenance=none`, the script is missing, or a question that decides a finding stays open'
  flat "$ROOT/$f" | grep -qF -- "$n" && ok "(j) $f: protocol rule" || bad "(j) $f missing the protocol rule"
  flat "$ROOT/$f" | grep -qF -- 'it runs `.claude/bin/blast-radius.sh' && bad "(j) $f keeps the form without bash" || ok "(j) $f: protocol names bash"
done

# (l2-v1..v6) reviewer routine uses the header lines and the precheck's br lines; (l2-v7..v9) protocol wording.
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  i=1
  for n in 'yourself with `--blast-radius` appended' \
           'Its `br ` lines in the precheck packet you ran are this run; do not run the script again. A `br blast-radius: unavailable` line means the script is missing.' \
           "The dispatch header's \`Constitution:\` line answers whether it exists" \
           "read the dispatch header's \`Review gating:\` line first; only when it is absent, read the key with" \
           'A deferred criterion that runs the full suite, run with `--criterion <n>`, is that one run.' \
           'Do not inspect `.claude/bin`, `.claude/hooks` or `.claude/persona-config.json` for what the header states'; do
    flat "$ROOT/$f" | grep -qF -- "$n" && ok "(l2-v$i) $f" || bad "(l2-v$i) $f missing: $n"
    i=$((i+1))
  done
done
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/reviewer.md .claude/agents/orchestrator.md; do
  flat "$ROOT/$f" | grep -qF -- 'Its `review-precheck.sh --blast-radius` run counts.' && ok "(l2-v7) $f" || bad "(l2-v7) $f missing the run-counts sentence"
done
for f in templates/persona-protocol.md .claude/persona-protocol.md; do
  flat "$ROOT/$f" | grep -qF -- 'puts `defer: <reason>` on the first line of each flag that currently exists and keeps the rest' && ! flat "$ROOT/$f" | grep -qF 'overwrite a flag' && ok "(l2-v8) $f" || bad "(l2-v8) $f escape hatch"
  flat "$ROOT/$f" | grep -qF -- "a pending-review flag left by its writer's stop, a \`fail\`, an \`escalate\` or no \`check:\` line moves the unit to \`medium\`, so it gets the reviewer" && ok "(l2-v9) $f" || bad "(l2-v9) $f small lane"
done

exit "$fail"
