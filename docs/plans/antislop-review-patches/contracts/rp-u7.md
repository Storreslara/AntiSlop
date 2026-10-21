Unit: rp-u7

## Objective
The qw-u5 review notes (82844f70, 0.31.193), spec Step 8. After this unit:
- `templates/persona-protocol.md` "Reuse over re-derivation" says the reviewer runs
  `bash .claude/bin/blast-radius.sh <baseline>`, the same command `agents/reviewer.md` names.
- `bin/blast-radius.sh` counts as a test only a path under `tests/` or `__tests__/`, or a `.test`/`.spec`
  (or `_test`/`_spec`) name with a code extension, so `docs/specs/` and `*_spec.md` are callers; it builds
  each output line with `printf` instead of a `sed` replacement, so a path holding `|`, `&` or `\` is
  printed as is; it runs git with `-c core.quotePath=false`, so a non-ASCII path is printed unquoted and
  its callers are found; and it prints at most 300 lines after the header, then `truncated: <n> more
  lines`. The header line and the per-file cap of 40 are unchanged.
- this repo's `.claude/bin/blast-radius.sh` is committed as mode 100755 (it was 100644), and
  `tests/bin-helpers-scaffold.test.sh` checks that every installed helper is executable in a fresh
  scaffold, after `--update` restores it, and in this repo's own git index.
`tests/blast-radius.test.sh` gains cases (k) to (n) and the `bash` prose row. This is spec Step 8.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 8 (rp-u7)" and
Clarifications (Open Question 6, ruled 2026-10-20). This file is the contract of record. Dispatch after
st-u4 and before rp-u4 (st-u2 edits the same protocol paragraph; the anchor check ran against st-u2's
payloads).

## Affected files
- `tests/blast-radius.test.sh` (anchors: line matching `# (j) prose: the reviewer and the protocol name the script and the explorer triggers (operator ruling c1).`; line matching `  n='it runs`)
- `tests/bin-helpers-scaffold.test.sh` (anchors: line matching `then ok "(b) harness-integrity.sh absent"`; line matching `then ok "(e) --update restores helpers"`)
- `bin/blast-radius.sh` (anchors: line matching `mapfile -t changed < <(git diff --name-only "$1..HEAD")`; line matching `TESTRE=`; line matching `  hits="$(git grep -l -I -w -F`; line matching `  lines="$( {`; line matching `printf '%s' "$body"`)
- `templates/persona-protocol.md` (anchor: line matching `re-derives it with a script: it runs`)
- `.claude/bin/blast-radius.sh` (mode 100644 to 100755, by edit 15; content only through `node bin/cli.js --update`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/bin/blast-radius.sh`, `.claude/persona-protocol.md`,
  `.claude/agents/*.md` (every full-tier mirror inlines "Structural questions"), `.claude/protocol-digest.md`,
  the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/blast-radius.test.sh`
   anchor: line matching `# (j) prose: the reviewer and the protocol name the script and the explorer triggers (operator ruling c1).`
   indent: 0
   before: `# (j) prose: the reviewer and the protocol name the script and the explorer triggers (operator ruling c1).`
   after:
~~~
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
~~~
2. file: `tests/blast-radius.test.sh`
   anchor: line matching `  n='it runs` (the only such line, inside the protocol loop)
   indent: 0
   before:
~~~
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/reviewer.md .claude/agents/orchestrator.md; do
  n='it runs `.claude/bin/blast-radius.sh <baseline>` itself and spawns the `explorer` only when the script prints `provenance=none`, the script is missing, or a question that decides a finding stays open'
  flat "$ROOT/$f" | grep -qF -- "$n" && ok "(j) $f: protocol rule" || bad "(j) $f missing the protocol rule"
done
~~~
   after:
~~~
for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/reviewer.md .claude/agents/orchestrator.md; do
  n='it runs `bash .claude/bin/blast-radius.sh <baseline>` itself and spawns the `explorer` only when the script prints `provenance=none`, the script is missing, or a question that decides a finding stays open'
  flat "$ROOT/$f" | grep -qF -- "$n" && ok "(j) $f: protocol rule" || bad "(j) $f missing the protocol rule"
  flat "$ROOT/$f" | grep -qF -- 'it runs `.claude/bin/blast-radius.sh' && bad "(j) $f keeps the form without bash" || ok "(j) $f: protocol names bash"
done
~~~
3. file: `tests/bin-helpers-scaffold.test.sh`
   anchor: line matching `then ok "(b) harness-integrity.sh absent"`
   indent: 0
   before: `if [ ! -e .claude/bin/harness-integrity.sh ]; then ok "(b) harness-integrity.sh absent"; else bad "(b) harness-integrity.sh absent"; fi`
   after:
~~~
if [ ! -e .claude/bin/harness-integrity.sh ]; then ok "(b) harness-integrity.sh absent"; else bad "(b) harness-integrity.sh absent"; fi
# rp-u7: every helper is executable in a fresh scaffold, after --update restores it, and in this repo's own index.
check_exec() {
  local f miss=0
  for f in $FILES; do [ -x ".claude/bin/$f" ] || miss=1; done
  [ "$miss" = 0 ]
}
if check_exec; then ok "(f) scaffolded helpers executable"; else bad "(f) scaffolded helpers executable"; fi
idx="$(git -C "$ROOT" ls-files -s -- .claude/bin 2>/dev/null)"
nonexec="$(printf '%s\n' "$idx" | awk 'NF && $1 != "100755" {print $4}')"
if [ -n "$idx" ] && [ -z "$nonexec" ]; then ok "(g) this repo's .claude/bin helpers are committed executable"; else bad "(g) committed without +x: ${nonexec:-no index entries}"; fi
~~~
4. file: `tests/bin-helpers-scaffold.test.sh`
   anchor: line matching `then ok "(e) --update restores helpers"`
   indent: 0
   before: `if check_files; then ok "(e) --update restores helpers"; else bad "(e) --update restores helpers"; fi`
   after:
~~~
if check_files; then ok "(e) --update restores helpers"; else bad "(e) --update restores helpers"; fi
if check_exec; then ok "(h) restored helpers executable"; else bad "(h) restored helpers executable"; fi
~~~
5. command: `bash -c 'bash tests/blast-radius.test.sh 2>/dev/null | grep -c "^FAIL"; bash tests/bin-helpers-scaffold.test.sh | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `14` then `1`. In the first test, rows (k) `docs/specs/` and `*_spec.md`, (l), (m), the two (n) count rows, and the four (j) protocol rows with their four `bash` rows fail; in the second, row (g) fails because this repo's index holds `.claude/bin/blast-radius.sh` as 100644.
6. file: `bin/blast-radius.sh`
   anchor: line matching `mapfile -t changed < <(git diff --name-only "$1..HEAD")`
   indent: 0
   before: `mapfile -t changed < <(git diff --name-only "$1..HEAD")`
   after: `mapfile -t changed < <(git -c core.quotePath=false diff --name-only "$1..HEAD")`
7. file: `bin/blast-radius.sh`
   anchor: line matching `TESTRE=`
   indent: 0
   before:
~~~
CAP=40
TESTRE='(^|/)(tests?|__tests__|specs?)/|[._-](test|spec)\.[A-Za-z0-9]+$'
~~~
   after:
~~~
CAP=40
# rp-u7: at most MAXLINES lines after the header, then one `truncated: <n> more lines` line.
MAXLINES=300
# rp-u7: a test is a path under tests/ or __tests__/, or a .test/.spec (or _test/_spec) name with a code
# extension; docs/specs/ and *_spec.md are not tests.
TESTRE='(^|/)(tests|__tests__)/|[._-](test|spec)\.(sh|bash|js|cjs|mjs|jsx|ts|tsx|py|rb|go|rs)$'
# rp-u7: prints "<kind>: <path> -> <changed file>" per input line; no sed, so `|`, `&` and `\` in a path are kept.
emit() { local h; while IFS= read -r h; do if [ -n "$h" ]; then printf '%s: %s -> %s\n' "$1" "$h" "$2"; fi; done; }
~~~
8. file: `bin/blast-radius.sh`
   anchor: line matching `  hits="$(git grep -l -I -w -F`
   indent: 2
   before: `  hits="$(git grep -l -I -w -F "${args[@]}" -- . 2>/dev/null)"; rc=$?`
   after: `  hits="$(git -c core.quotePath=false grep -l -I -w -F "${args[@]}" -- . 2>/dev/null)"; rc=$?`
9. file: `bin/blast-radius.sh`
   anchor: line matching `  lines="$( {`
   indent: 2
   before: `  lines="$( { [ -z "$tests" ] || printf '%s\n' "$tests" | sed "s|^|test: |; s|\$| -> $p|"; [ -z "$callers" ] || printf '%s\n' "$callers" | sed "s|^|caller: |; s|\$| -> $p|"; } )"`
   after: `  lines="$(printf '%s\n' "$tests" | emit test "$p"; printf '%s\n' "$callers" | emit caller "$p")"`
10. file: `bin/blast-radius.sh`
   anchor: line matching `printf '%s' "$body"` (the last but one line)
   indent: 0
   before: `printf '%s' "$body"`
   after:
~~~
n="$(printf '%s' "$body" | wc -l | tr -d ' ')"
printf '%s' "$body" | sed -n "1,${MAXLINES}p"
if [ "$n" -gt "$MAXLINES" ]; then echo "truncated: $((n - MAXLINES)) more lines"; fi
~~~
11. file: `templates/persona-protocol.md`
   anchor: line matching `re-derives it with a script: it runs` ("Reuse over re-derivation"; the only such line)
   indent: 0
   before:
~~~
re-derives it with a script: it runs `.claude/bin/blast-radius.sh <baseline>`
~~~
   after:
~~~
re-derives it with a script: it runs `bash .claude/bin/blast-radius.sh <baseline>`
~~~
12. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected one above what st-u4 wrote, 0.31.201 to 0.31.202 with no fix rounds).
13. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Blast-radius script follow-ups (rp-u7, VERSION).** bin/blast-radius.sh: a test is a path under tests/ or __tests__/, or a .test/.spec (or _test/_spec) name with a code extension, so docs/specs/ and *_spec.md are callers; output lines are built with printf instead of a sed replacement, so `|`, `&` and `\` in a path survive; git runs with core.quotePath=false, so non-ASCII paths are unquoted; at most 300 lines follow the header, then `truncated: <n> more lines`. templates/persona-protocol.md names `bash .claude/bin/blast-radius.sh <baseline>`, as agents/reviewer.md does. This repo's .claude/bin/blast-radius.sh is committed executable; tests/bin-helpers-scaffold.test.sh checks every helper's mode. New cases in tests/blast-radius.test.sh.
~~~
   Replace `VERSION` with the version that edit 12 wrote.
14. command: `node bin/cli.js --update`
   expect: 0
15. command: `git update-index --chmod=+x .claude/bin/blast-radius.sh`
   expect: 0
   This stages the file with mode 100755 (git plumbing; no content change beyond what edit 14 wrote).
16. command: `bash tests/blast-radius.test.sh`
   expect: 0
17. command: `bash tests/bin-helpers-scaffold.test.sh`
   expect: 0
18. command: `git add -u && git commit -m "fix(rp-u7): blast-radius script counts only tests/ as tests, keeps odd paths, caps its output; helpers committed executable"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `bin/cli.js` (restoring the mode of a content-current helper on `--update` is more than a one-line change; recorded in the spec as a residual; criterion 6)
- `agents/reviewer.md` (it already names `bash .claude/bin/blast-radius.sh`; criterion 6)
- `tests/review-precheck.test.sh` and the precheck sentence st-u2 added to the protocol (its wording stays; criterion 6)
- `adapters/` (no `.claude/bin/` and no blast-radius rule there; criterion 6)

## Acceptance criteria
1. run: `bash -c 'bash tests/blast-radius.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: restore the old `TESTRE` line (edit 7's `before:`); rows (k) `docs/specs/` and `*_spec.md` fail and stdout is `1`.
2. run: `bash -c 'bash tests/bin-helpers-scaffold.test.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: `git update-index --chmod=-x .claude/bin/blast-radius.sh`; row (g) fails and stdout is `1`.
3. run: `bash -c 'cmp bin/blast-radius.sh .claude/bin/blast-radius.sh && l=$(git log --format=%H --grep="^[a-z]*(rp-u7): " | head -1) && git ls-tree "$l" -- .claude/bin/ | grep -v "^100755 " | wc -l'`
   exit: 0
   stdout: `0`
   mutation: skip edit 14 (`--update`); `cmp` reports a difference and the command exits 1. Skip edit 15 on a clone with `core.fileMode=false`; the count is `1`.
4. run: `bash -c 'for f in templates/persona-protocol.md .claude/persona-protocol.md .claude/agents/reviewer.md .claude/agents/lead-programmer.md; do tr -s " \n" " " < "$f" | tr -d "\140" | grep -c "it runs bash .claude/bin/blast-radius.sh <baseline> itself and spawns the explorer only when"; done | tr "\n" " "'`
   exit: 0
   stdout: `1 1 1 1 `
   mutation: skip edit 11; stdout is `0 0 0 0 ` and the command exits 0 (the last `tr` sets the status).
5. run: `bash -c 'd=$(mktemp -d); cd "$d" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m b && for i in $(seq 1 400); do printf "x\n" > "f$i.txt"; done && git add -A && git -c user.email=t@t -c user.name=t commit -q -m c && bash "$OLDPWD/bin/blast-radius.sh" HEAD~1 | tail -n1'`
   exit: 0
   stdout: `truncated: 100 more lines`
   mutation: delete the last `if [ "$n" -gt "$MAXLINES" ]` line of edit 10; stdout is `changed: f369.txt` (the 300th line; git lists `f1.txt` to `f400.txt` in byte order).
6. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u7): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u7): " | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | LC_ALL=C sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md bin/blast-radius.sh package.json templates/persona-protocol.md tests/bin-helpers-scaffold.test.sh tests/blast-radius.test.sh `
   mutation: also edit `bin/cli.js` in an rp-u7 commit; it joins the list.
7. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u7): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u7): " | head -1); bash hooks/scripts/version-stamp-check.sh "$b^..$l" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 12; stdout reads `version-stamp-check: violation touched: yes`.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/blast-radius.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edits 1 to 4 add the cases; edit 5 shows them red (`14`, `1`) before the code edits 6 to 11.
ruling: Open Question 6, 2026-10-20: no new explorer trigger; the reviewer's triggers stay `provenance=none`, the script missing, and an open question that decides a finding.
printf-not-awk: the spec suggested `awk -v`; `awk -v` rewrites backslash escapes in the value, so a path holding `\` would still change. `emit` is a `while read` loop with `printf '%s'`, which copies every byte.
mode: `--update` already writes a helper whose content changed with the packaged file's mode (`bin/cli.js` `writeSpecBody`, `fs.chmodSync`), so edit 14 makes the working copy 755 because edit 7 changes the content; edit 15 makes the index say so even on a clone with `core.fileMode=false`. Restoring the mode of a helper whose content is current needs a new branch in the update loop: a residual, not this unit.
proof: spec-master applied edits 1 to 18 to a scratch clone (8b931f0f plus rp-u1 to rp-u3, qw-u6 and st-u1 to st-u4, each applied from its contract) with a script that requires each `before:` payload to occur exactly once: every payload matched once, edit 5 printed `14` and `1`, edits 16 and 17 exited 0, and criteria 1 to 7 printed the stated stdout. validate.sh was not run by spec-master.
chained: st-u2 edit 7 appends a sentence after "or the writer." in the same paragraph; edit 11's line is two lines above it and unchanged by st-u2. st-u2 and st-u4 change the `FILES=` line and the `(a)` label in tests/bin-helpers-scaffold.test.sh; edits 3 and 4 anchor on the (b) and (e) lines, which no queued unit edits. No queued contract edits bin/blast-radius.sh or tests/blast-radius.test.sh.
blast-radius: bin/blast-radius.sh:10, :12-13, :20, :26, :32; templates/persona-protocol.md:41; tests/blast-radius.test.sh:58, :69-72; tests/bin-helpers-scaffold.test.sh:23, :39. Callers: agents/reviewer.md:18-19 (runs the script), bin/cli.js:656 (`BIN_HELPER_FILES`), tests/validate.sh:759. Line numbers are at c02b286a; work from the anchors.
version: .claude-plugin/plugin.json and package.json read 0.31.194 while rp-u1 is in flight and, with no fix rounds, 0.31.201 after st-u4; edit 12 adds one to whatever they read when the unit starts.
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2); the mode of `.claude/bin/blast-radius.sh` changes through edit 15.
commit-message: fix(rp-u7): blast-radius script counts only tests/ as tests, keeps odd paths, caps its output; helpers committed executable
diagnosis: none
review-packet:
~~~
unit: rp-u7
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
~~~

## Escalation
If a `before:` payload is not found verbatim (a queued unit may have edited a neighbouring line), stop and
report the current text. If `git ls-files -s .claude/bin` shows a helper other than `blast-radius.sh` with
mode 100644, stop and report it (that helper belongs to another unit). If a gate blocks a command,
including `git update-index`, report it and wait. Anything outside "Affected files" goes to your report as
a proposal.
