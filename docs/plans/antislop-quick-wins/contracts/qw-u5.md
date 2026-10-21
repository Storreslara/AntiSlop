Unit: qw-u5

## Objective
Operator ruling c1 (OQ1 = a, "script first"): the reviewer derives a change's blast radius itself with a new
deterministic script and spawns the explorer only when the script has no answer.
- New `bin/blast-radius.sh <baseline>`, installed to `.claude/bin/` through `BIN_HELPER_FILES`. For each
  file changed in `<baseline>..HEAD` it lists the tracked files that name it (`git grep`, whole word, on the
  basename and on the stem when the stem has 4 or more characters), classed as `test:` or `caller:`, at most
  40 per changed file. Line 1 is `blast-radius: provenance=<grep|none> files=<n>`; `none` means the range is
  empty or the search failed. Read-only.
- `agents/reviewer.md`: "Scope the review via the explorer" becomes "Scope the review with the blast-radius
  script"; the advisory-packet bullet says the reviewer derives blast radius itself (script, or explorer when
  the script has no answer).
- `templates/persona-protocol.md`, "Structural questions go to the explorer": the reuse rule's reviewer
  sentence is amended by the operator's ruling (wording under Pre-resolved context, `amended-rule`), and the
  section's first paragraph points to it. Independence is kept: the reviewer runs the script itself and never
  takes a blast radius from the dispatch, the orchestrator or the writer.

The script and the prose ship in this one unit: prose naming a script that is not installed would send the
reviewer to the explorer fallback on every review, and a script nobody is told to run changes nothing. The
codex and cursor ports install no `.claude/bin/`, so their reviewers keep the explorer and are not edited.
This is spec Step 5.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-quick-wins/spec.md`, "Step 5 (qw-u5)" and "Context,
c1". This file is the contract of record. Dispatch it only after qw-u4 has reached PASS (shared template and
bump files; it extends qw-u1's `BIN_HELPER_FILES` and scaffold test).

## Affected files
- `tests/blast-radius.test.sh` (anchor: new file, mode 755)
- `bin/blast-radius.sh` (anchor: new file, mode 755)
- `bin/cli.js` (anchor: line matching `const BIN_HELPER_FILES = [`)
- `tests/bin-helpers-scaffold.test.sh` (anchor: line matching `FILES="ladder-tier.sh`)
- `agents/reviewer.md` (anchors: line matching `- **Scope the review via the explorer**`; line matching `  verification: still derive blast radius via the explorer and re-run the`)
- `templates/persona-protocol.md` (section `## Structural questions go to the explorer`: line ending `and names what is missing in its report.`; line matching `never applies to the reviewer, which always re-derives blast radius and`)
- `tests/validate.sh` (anchor: line matching `echo "== unit-bookkeeping: one call per phase for tier, RULING lines and dispatch header (Bash, qw-u1) =="`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/bin/blast-radius.sh`, `.claude/agents/*.md` (the six full-tier mirrors inline "Structural questions"; reviewer also its body), `.claude/persona-protocol.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/blast-radius.test.sh`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
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
~~~
2. command: `bash tests/blast-radius.test.sh`
   expect: 1
   The red step: the script does not exist yet and the prose rows (j) fail.
3. file: `bin/blast-radius.sh`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
#!/usr/bin/env bash
# blast-radius.sh (qw-u5): file-level blast radius of <baseline>..HEAD for the reviewer, who runs it itself.
# For each changed file, git grep finds tracked files naming it (basename, and stem when 4+ chars).
# Read-only: never writes a file.
set -uo pipefail
[ "$#" -eq 1 ] || { echo "usage: blast-radius.sh <baseline>" >&2; exit 2; }
top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "blast-radius: not a git repository" >&2; exit 2; }
cd "$top" || exit 2
git rev-parse --verify -q "$1^{commit}" >/dev/null || { echo "blast-radius: baseline does not resolve: $1" >&2; exit 2; }
mapfile -t changed < <(git diff --name-only "$1..HEAD")
if [ "${#changed[@]}" -eq 0 ]; then echo "blast-radius: provenance=none files=0"; exit 0; fi
CAP=40
TESTRE='(^|/)(tests?|__tests__|specs?)/|[._-](test|spec)\.[A-Za-z0-9]+$'
body=""; failed=0
for p in "${changed[@]}"; do body+="changed: $p"$'\n'; done
for p in "${changed[@]}"; do
  b="${p##*/}"; s="${b%.*}"
  args=(-e "$b")
  if [ "$s" != "$b" ] && [ "${#s}" -ge 4 ]; then args+=(-e "$s"); fi
  hits="$(git grep -l -I -w -F "${args[@]}" -- . 2>/dev/null)"; rc=$?
  if [ "$rc" -gt 1 ]; then failed=1; continue; fi
  hits="$(printf '%s\n' "$hits" | grep -vxF -- "$p" | grep -v '^$' || true)"
  [ -n "$hits" ] || continue
  tests="$(printf '%s\n' "$hits" | grep -E -- "$TESTRE" || true)"
  callers="$(printf '%s\n' "$hits" | grep -vE -- "$TESTRE" || true)"
  lines="$( { [ -z "$tests" ] || printf '%s\n' "$tests" | sed "s|^|test: |; s|\$| -> $p|"; [ -z "$callers" ] || printf '%s\n' "$callers" | sed "s|^|caller: |; s|\$| -> $p|"; } )"
  total="$(printf '%s\n' "$lines" | wc -l | tr -d ' ')"
  body+="$(printf '%s\n' "$lines" | head -n "$CAP")"$'\n'
  if [ "$total" -gt "$CAP" ]; then body+="truncated: $p shown=$CAP total=$total"$'\n'; fi
done
if [ "$failed" = 1 ]; then echo "blast-radius: provenance=none files=${#changed[@]}"; else echo "blast-radius: provenance=grep files=${#changed[@]}"; fi
printf '%s' "$body"
exit 0
~~~
4. file: `bin/cli.js`
   anchor: line matching `const BIN_HELPER_FILES = [`
   indent: 0
   before: `const BIN_HELPER_FILES = ['ladder-tier.sh', 'contract-guard.js', 'contract-score.js', 'fail-count.sh', 'escalation-card.sh', 'unit-bookkeeping.sh'];`
   after: `const BIN_HELPER_FILES = ['ladder-tier.sh', 'contract-guard.js', 'contract-score.js', 'fail-count.sh', 'escalation-card.sh', 'unit-bookkeeping.sh', 'blast-radius.sh'];`
5. file: `tests/bin-helpers-scaffold.test.sh`
   anchor: line matching `FILES="ladder-tier.sh`
   indent: 0
   before: `FILES="ladder-tier.sh contract-guard.js contract-score.js fail-count.sh escalation-card.sh unit-bookkeeping.sh"`
   after: `FILES="ladder-tier.sh contract-guard.js contract-score.js fail-count.sh escalation-card.sh unit-bookkeeping.sh blast-radius.sh"`
   In the same file, change both occurrences of `(a) six helpers present` to `(a) seven helpers present`.
6. file: `agents/reviewer.md`
   anchor: line matching `- **Scope the review via the explorer**`
   indent: 0
   before:
~~~
- **Scope the review via the explorer**: spawn it for the change's blast
  radius, then review exactly the affected files, callers, and their tests —
  not the whole repo, and not just the literal diff (a clean diff can still
  break a caller two hops away). Ask the explorer which impacted paths lack
  test coverage and treat uncovered impact as a finding.
~~~
   after:
~~~
- **Scope the review with the blast-radius script**: run
  `bash .claude/bin/blast-radius.sh <baseline>` yourself, from the repo root,
  and never take a blast radius from the dispatch, the orchestrator or the
  writer. It prints `blast-radius: provenance=<grep|none> files=<n>`, then
  `changed:`, `test:` and `caller:` lines. Review exactly the changed files and
  the callers and tests it lists — not the whole repo, and not just the
  literal diff (a clean diff can still break a caller two hops away). A
  changed source file with no `test:` line is uncovered impact; treat it as a
  finding. Spawn the explorer only when the script prints `provenance=none`,
  the script is missing, or a question that decides a finding stays open (a
  caller two hops away, or a symbol-level call that a file-name search cannot
  see).
~~~
7. file: `agents/reviewer.md`
   anchor: line matching `  verification: still derive blast radius via the explorer and re-run the`
   indent: 2
   before:
~~~
  verification: still derive blast radius via the explorer and re-run the
  checks yourself. An incomplete or insufficient packet is a trigger for
~~~
   after:
~~~
  verification: still derive blast radius yourself (the blast-radius script,
  or the explorer when the script has no answer) and re-run the checks
  yourself. An incomplete or insufficient packet is a trigger for
~~~
8. file: `templates/persona-protocol.md`
   anchor: line ending `and names what is missing in its report.` (the only such line; first paragraph of "Structural questions go to the explorer")
   indent: 0
   before:
~~~
`## Pre-resolved context`, and names what is missing in its report.
~~~
   after:
~~~
`## Pre-resolved context`, and names what is missing in its report. The
reviewer's blast-radius rule is under **Reuse over re-derivation** below.
~~~
9. file: `templates/persona-protocol.md`
   anchor: line matching `never applies to the reviewer, which always re-derives blast radius and`
   indent: 0
   before:
~~~
never applies to the reviewer, which always re-derives blast radius and
re-runs the checks itself regardless of what the packet claims.
~~~
   after:
~~~
never applies to the reviewer, which always re-derives blast radius and
re-runs the checks itself regardless of what the packet claims. The reviewer
re-derives it with a script: it runs `.claude/bin/blast-radius.sh <baseline>`
itself and spawns the `explorer` only when the script prints
`provenance=none`, the script is missing, or a question that decides a finding
stays open; it never takes a blast radius from the dispatch, the orchestrator
or the writer.
~~~
10. file: `tests/validate.sh`
   anchor: line matching `echo "== unit-bookkeeping: one call per phase for tier, RULING lines and dispatch header (Bash, qw-u1) =="`
   indent: 0
   before:
~~~
echo "== unit-bookkeeping: one call per phase for tier, RULING lines and dispatch header (Bash, qw-u1) =="
if bash tests/unit-bookkeeping.test.sh > /dev/null; then
  echo "OK   tests/unit-bookkeeping.test.sh"
else
  echo "FAIL tests/unit-bookkeeping.test.sh"
  fail=1
fi
~~~
   after:
~~~
echo "== unit-bookkeeping: one call per phase for tier, RULING lines and dispatch header (Bash, qw-u1) =="
if bash tests/unit-bookkeeping.test.sh > /dev/null; then
  echo "OK   tests/unit-bookkeeping.test.sh"
else
  echo "FAIL tests/unit-bookkeeping.test.sh"
  fail=1
fi

echo
echo "== blast-radius: the reviewer's own file-level blast radius, explorer only as fallback (Bash, qw-u5) =="
if bash tests/blast-radius.test.sh > /dev/null; then
  echo "OK   tests/blast-radius.test.sh"
else
  echo "FAIL tests/blast-radius.test.sh"
  fail=1
fi
~~~
11. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.190 to 0.31.191).
12. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Reviewer blast radius by script (qw-u5, VERSION).** Operator ruling c1: new `bin/blast-radius.sh <baseline>`, installed to `.claude/bin/`, lists for each file changed in the range the tracked files that name it (`test:` or `caller:`, at most 40 each) under a `provenance=<grep|none>` header. The reviewer runs it itself and spawns the explorer only on `provenance=none`, a missing script, or an open question that decides a finding; the protocol's "Reuse over re-derivation" rule states the same, and the reviewer still never takes a blast radius from the dispatch, the orchestrator or the writer. The codex and cursor reviewers keep the explorer. New test tests/blast-radius.test.sh.
~~~
   Replace `VERSION` with the version that edit 11 wrote.
13. command: `node bin/cli.js --update`
   expect: 0
14. command: `bash tests/blast-radius.test.sh`
   expect: 0
15. command: `git add tests/blast-radius.test.sh bin/blast-radius.sh .claude/bin/blast-radius.sh && git add -u && git commit -m "feat(qw-u5): the reviewer derives blast radius with a script it runs itself; explorer only as fallback"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md` and the two adapter protocol ports (their scaffolds install no `.claude/bin/`; criterion 5)
- `hooks/` and `.claude/hooks/` (no gate change; the script is advisory input to the reviewer, not a gate)
- `agents/orchestrator.md` (the orchestrator does not run or forward the script; criterion 5)
- `agents/explorer.md` (the explorer is unchanged; it is still the fallback)
- `.claude/agents/` and `.claude/bin/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/blast-radius.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: drop the self-exclusion (`grep -vxF -- "$p"`) from the script; case (a) prints `FAIL (a) self listed` and stdout is `1` (spec-master ran this mutation).
2. run: `cmp bin/blast-radius.sh .claude/bin/blast-radius.sh`
   exit: 0
   stdout: empty
   mutation: revert edit 4; `--update` installs nothing, cmp reports the missing file and exits 2.
3. run: `bash -c 'bash tests/bin-helpers-scaffold.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: revert edit 4; the scaffold has no `.claude/bin/blast-radius.sh`, case (a) fails and stdout is `1`.
4. run: `bash -c 'bash .claude/bin/blast-radius.sh HEAD~1 | head -n1 | grep -cE "^blast-radius: provenance=grep files=[1-9][0-9]*$"'`
   exit: 0
   stdout: `1`
   mutation: make the script print `provenance=none` unconditionally; stdout is `0` and the exit is 1.
5. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u5)" | tail -1); git diff --name-only "$b^..HEAD" -- adapters hooks .claude/hooks agents/orchestrator.md agents/explorer.md | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `adapters/cursor/agents/reviewer.md` in a qw-u5 commit; stdout is at least `1`.
6. run: `bash -c 'node tests/adapter-protocol-parity.test.js >/dev/null && node tests/protocol-doc-drift.test.js >/dev/null && node tests/protocol-cross-references.test.js >/dev/null && bash tests/persona-prose-pins.test.sh >/dev/null && node tests/cli-backfill.test.js >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: add a line starting `## ` inside edit 9's payload; protocol-doc-drift's section count no longer matches and stdout is `1`.
7. run: `bash -c 'b=$(git log --format=%H --grep="(qw-u5)" | tail -1); bash hooks/scripts/version-stamp-check.sh "$b^..HEAD" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 11; stdout reads `version-stamp-check: violation touched: yes`.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/blast-radius.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes the test (edit 1) fails first (edit 2). spec-master ran edits 1 to 3 and 6 to 9 plus the `BIN_HELPER_FILES` change on a clone (1d4abf5a plus qw-u4): all 29 checks pass, `cmp` is clean after `--update`, and the parity, doc-drift, cross-reference, prose-pin and cli-backfill suites stay green. The script took about 2 s on a 27-file range of this repo.
amended-rule: the protocol's "it never applies to the reviewer, which always re-derives blast radius and re-runs the checks itself regardless of what the packet claims" is kept word for word and extended by the operator's ruling (2026-10-20, c1 = a) with: "The reviewer re-derives it with a script: it runs `.claude/bin/blast-radius.sh <baseline>` itself and spawns the `explorer` only when the script prints `provenance=none`, the script is missing, or a question that decides a finding stays open; it never takes a blast radius from the dispatch, the orchestrator or the writer." Independence property: the reviewer runs the script itself, and no other persona's output stands in for it.
script-design: grep only, no graph mode. spec-master measured `code-review-graph impact` on this repo: at `--depth 1` a shell script had 0 cross-file edges; at the default depth two changed files gave 1422 impacted nodes, mostly unrelated. A file-name search finds what this repo's tests and docs actually reference (`bash bin/ladder-tier.sh`, `require('./store')`). Symbol-level and two-hop questions stay with the explorer, which is the named fallback.
blast-radius: agents/reviewer.md:18-22 and :85-89, templates/persona-protocol.md:11-38 (Structural questions; in UNIVERSAL_PROTOCOL_CORE, so every full-tier mirror re-renders, about +400 bytes each, reviewer +936 with its body), bin/cli.js:655 (BIN_HELPER_FILES; only the Claude scaffold at :2541 and runUpdate at :1313 install it), tests/bin-helpers-scaffold.test.sh:15. Line numbers are at 1d4abf5a; work from the anchors.
pins-searched: no test pins "Scope the review via the explorer", "via the explorer" or "always re-derives blast radius" (searched tests/, bin/, README.md, CONTEXT.md, docs/). docs/harness-glossary.md's F11 entry ("the reviewer ... always re-derives blast radius independently") stays true; ADR-0013 is history and is not edited.
four-copy: the codex and cursor reviewer ports and protocol ports keep the explorer text; their scaffolds never install `.claude/bin/` (bin/cli.js scaffoldCursor and scaffoldCodex do not call buildBinHelperSpecs).
version: .claude-plugin/plugin.json and package.json read 0.31.190 after qw-u4 if no fix round bumped; edit 11 adds one (expected 0.31.191).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: feat(qw-u5): the reviewer derives blast radius with a script it runs itself; explorer only as fallback
diagnosis: none
review-packet:
~~~
unit: qw-u5
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
If a `before:` payload is not found verbatim (qw-u1 changes `BIN_HELPER_FILES` and the scaffold test; aof-u3
changed reviewer.md's Materiality bullet, not these), stop and report the current text. If `node bin/cli.js
--update` refuses (for example the cross-reference assertion), quote its message and stop. If a gate blocks a
command, report it and wait. Anything outside "Affected files" goes to your report as a proposal.
