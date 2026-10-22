Unit: rp-u15

## Objective
Fix round 1 for rp-u15 (fix-of: 2026-10-22T17:25:51Z; the implementer runs on sonnet). The writer scope gate gives `us_named_in` the raw dispatch prompt, so a scribe or spec-master whose dispatch names a file at the end of a sentence (`... eval/abtest/README.md. Changed API ...`) and commits it with `git commit -q` is blocked and told to revert the edit its dispatch asked for. After this fix the gate hands `us_named_in` a tokenised copy of the prompt (cut at whitespace and delimiters, trailing sentence punctuation and a leading `./` stripped, inner dots kept), a table of 28 prose shapes proves it for both personas, a block lists the commits after the baseline that the restore command would also revert, and `docs/trust-model.md` row 26 states the cases the gate does not check.

## Retrieval
Fast path, no tracker issue. This file is the fix contract of record for `Unit: rp-u15`; the original contract is `docs/plans/antislop-review-patches/contracts/rp-u15.md` (commit dfb5b89e), implemented at 65cd8b44 (version 0.31.209). The FAIL block it answers is the one timestamped 2026-10-22T17:25:51Z in the reviewer record for rp-u15.

## Affected files
- `tests/writer-scope-gate.test.sh` (anchor: line matching `g rm -qf -- src/staged.js; rm -f src/new.js; git checkout -q -- CONTEXT.md`)
- `hooks/scripts/writer-scope-gate.sh` (anchors: line matching `us_section "$W/prompt" "Affected files" > "$W/sec"`; line matching `us_named_in "$p" "$W/prompt" && [ "$persona" != lead-programmer ] && return 0`; line matching `viol=()`; line matching `    else echo "  rm -- $q   (a new file you never added)"`)
- `docs/trust-model.md` (anchor: line matching `| 26 | A writing persona (lead-programmer, scribe, spec-master) ends its turn`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- generated only, by `node bin/cli.js --update`: `.claude/hooks/scripts/writer-scope-gate.sh`, `.claude/agents/*.md`, `.claude/persona-protocol*.md`, `.claude/protocol-digest.md` (version stamps only), the config's `fileHashes` and `pluginVersion`

## Ordered edits

1. file: `tests/writer-scope-gate.test.sh`
   anchor: line matching `g rm -qf -- src/staged.js; rm -f src/new.js; git checkout -q -- CONTEXT.md`
   indent: 0
   before:
~~~
g rm -qf -- src/staged.js; rm -f src/new.js; git checkout -q -- CONTEXT.md
~~~
   after:
~~~
g rm -qf -- src/staged.js; rm -f src/new.js; git checkout -q -- CONTEXT.md
# rp-u15 fix 1: a path the dispatch names counts for scribe and spec-master whatever prose punctuation
# follows it. Every row is replayed through the gate for both personas in a scratch repo, the way
# abt-u13h's close-out scribe ran: one Edit tool call, the change committed with `git commit -q` (no
# commit line in the transcript), the commit dated after the transcript's first timestamp.
R2="$T/repo2"; mkdir -p "$R2/eval/abtest" "$R2/eval/other" "$R2/.claude" && cd "$R2" && git init -q . \
  && printf 'x\n' > eval/abtest/README.md && printf 'y\n' > eval/other/README.md && printf 'c\n' > CONTEXT.md \
  && printf '{"pluginVersion":"0"}\n' > .claude/persona-config.json && export CLAUDE_PROJECT_DIR="$R2" && g add -A \
  && GIT_COMMITTER_DATE=2000-01-01T00:00:00Z g commit -q --date=2000-01-01T00:00:00Z -m base2
B2="$(git rev-parse HEAD)"; NP=eval/abtest/README.md
named_row() { # <n> <named|unnamed> <prompt; @P@ is the path, \n a newline>
  local n="$1" want="$2" pr who; pr="$(printf '%b' "${3//@P@/$NP}")"
  for who in scribe spec-master; do
    g reset -q --hard "$B2"; printf 'row %s\n' "$n" >> "$NP"; dc -a -m "row $n"
    mkt "$T/n$n.$who" "$pr" "$R2/$NP"; run "$who" "$T/n$n.$who"
    if [ "$want" = named ]; then
      [ "$rc" = 0 ] && ok "(aa) $who row $n: path named" || bad "(aa) $who row $n should be named: rc=$rc $err"
    else
      [ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "scope: $NP." && ok "(aa) $who row $n: path not named" || bad "(aa) $who row $n should not be named: rc=$rc $err"
    fi
  done
}
named_row 1 named 'Scribe digest: affected files @P@. Changed API stays.'
named_row 2 named 'Edit `@P@` and nothing else.'
named_row 3 named 'Edit the readme (@P@.) today.'
named_row 4 named 'Edit @P@, then stop.'
named_row 5 named 'Edit @P@; then stop.'
named_row 6 named 'Files: @P@: add one line.'
named_row 7 named 'Edit @P@... then stop.'
named_row 8 named 'Edit @P@… then stop.'
named_row 9 named 'See [the readme](@P@) for it.'
named_row 10 named 'See @P@:12 for the line.'
named_row 11 named 'Is it @P@? Yes.'
named_row 12 named 'Do it in @P@!'
named_row 13 named 'Look at @P@:12.'
named_row 14 named 'Run:\n```\n@P@\n```\nthen stop.'
named_row 15 named 'Edit eval/other/README.md and @P@.'
named_row 16 named 'Edit @P@, eval/other/README.md.'
named_row 17 named 'Edit ./@P@ now.'
named_row 18 named 'Edit **@P@**. Done.'
named_row 26 named 'He said "edit @P@." and left.'
named_row 27 named "Edit '@P@.' now."
named_row 28 named 'Edit `@P@.` now.'
named_row 19 unnamed 'Edit x@P@ now.'
named_row 20 unnamed 'Edit @P@x now.'
named_row 21 unnamed 'Edit eval/other/README.md and README.md.'
named_row 22 unnamed 'Edit other/@P@.'
named_row 23 unnamed 'Edit @P@.bak now.'
named_row 24 unnamed 'Edit @P@/more now.'
named_row 25 unnamed 'Nothing is named here.'
# (ab) a block says when commits other than the writer's own changed the path after the baseline: the
# restore command would revert them too (another session's commit, or a commit made before the start
# and re-dated by an amend).
g reset -q --hard "$B2"; printf 'other\n' > CONTEXT.md; dc -a -m 'another session'; O="$(git rev-parse --short=10 HEAD)"
mkt "$T/w1" "$LP" "$R2/CONTEXT.md"; run lead-programmer "$T/w1"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "commit(s) $O" && printf '%s' "$err" | grep -qF 'not in your transcript' && ok "(ab) foreign commit named in the block" || bad "(ab) foreign rc=$rc $err"
cp "$T/w1" "$T/w2"; commit_result "$T/w2" "$(git rev-parse HEAD)"; run lead-programmer "$T/w2"
[ "$rc" = 2 ] && ! printf '%s' "$err" | grep -qF 'not in your transcript' && ok "(ab) the writer's own visible commit is not a foreign one" || bad "(ab) own rc=$rc $err"
g reset -q --hard "$B2"; printf 'early\n' > CONTEXT.md; GIT_COMMITTER_DATE=2000-06-01T00:00:00Z g commit -q -a --date=2000-06-01T00:00:00Z -m 'earlier unit'
GIT_COMMITTER_DATE=2099-01-03T00:00:00Z g commit -q --amend --no-edit --date=2099-01-03T00:00:00Z; O="$(git rev-parse --short=10 HEAD)"
run lead-programmer "$T/w1"
[ "$rc" = 2 ] && printf '%s' "$err" | grep -qF "commit(s) $O" && ok "(ab) re-dated earlier commit named in the block" || bad "(ab) amended rc=$rc $err"
g reset -q --hard "$B2"; cd "$R" && export CLAUDE_PROJECT_DIR="$R"
~~~
   The new block sits after the last line of case (z) and before case (l); its first line is the anchor line again. Cases (aa) and (ab) run in their own scratch repo (`$T/repo2`) and end by returning to `$R`.

2. command: `bash -c 'bash tests/writer-scope-gate.test.sh | /usr/bin/grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `18` (rows 1, 3, 7, 15, 17, 26, 27 and 28 of (aa) for both personas, and two (ab) lines fail against the 65cd8b44 gate).

3. file: `hooks/scripts/writer-scope-gate.sh`
   anchor: line matching `us_section "$W/prompt" "Affected files" > "$W/sec"`
   indent: 0
   before:
~~~
us_section "$W/prompt" "Affected files" > "$W/sec"
~~~
   after:
~~~
# ptok: the prompt as one token per line, so us_named_in reads a path the way a person does. Split at
# whitespace and at quotes, backticks, brackets, braces, angle brackets, `|`, `,`, `;` and `=`; then cut
# trailing sentence punctuation (`.,;:!?`) from each token, repeating until nothing more comes off, and
# a leading `./`. A `:12` or `#L12` line suffix needs no cutting: `:` and `#` already end a path token.
# Inner dots stay, so `xREADME.md`, `other/README.md` and `README.md.bak` are still different tokens.
# us_named_in alone counts a sentence-final `.` as part of the path, so a path that ends a sentence
# was never named (rp-u15 fix 1).
tr '[:space:]`()[]{}<>|,;=\047\042' '\n' < "$W/prompt" \
  | sed -E ':a; s/[.,;:!?]+$//; ta; s#^(\./)+##' > "$W/ptok"
us_section "$W/prompt" "Affected files" > "$W/sec"
~~~

4. file: `hooks/scripts/writer-scope-gate.sh`
   anchor: line matching `us_named_in "$p" "$W/prompt" && [ "$persona" != lead-programmer ] && return 0`
   indent: 0
   before:
~~~
  us_named_in "$p" "$W/prompt" && [ "$persona" != lead-programmer ] && return 0
~~~
   after:
~~~
  us_named_in "$p" "$W/ptok" && [ "$persona" != lead-programmer ] && return 0
~~~

5. file: `hooks/scripts/writer-scope-gate.sh`
   anchor: line matching `viol=()`
   indent: 0
   before:
~~~
viol=()
~~~
   after:
~~~
# foreign <path>: the short shas of the commits after the baseline that changed the path and that no
# commit line of the transcript shows. The restore command would revert them too (rp-u15 fix 1).
foreign() {
  local c s seen out=""
  while IFS= read -r c; do
    seen=0
    while IFS= read -r s; do [ -n "$s" ] || continue; case "$c" in "$s"*) seen=1; break ;; esac; done < "$W/shas"
    [ "$seen" = 1 ] || out="$out ${c:0:10}"
  done < <(git rev-list "$start..HEAD" -- "$1" 2>/dev/null)
  printf '%s' "${out# }"
}
viol=()
~~~

6. file: `hooks/scripts/writer-scope-gate.sh`
   anchor: line matching `    else echo "  rm -- $q   (a new file you never added)"`
   indent: 0
   before:
~~~
    else echo "  rm -- $q   (a new file you never added)"
    fi
~~~
   after:
~~~
    else echo "  rm -- $q   (a new file you never added)"
    fi
    f="$(foreign "$p")"
    [ -z "$f" ] || echo "    note: commit(s) $f changed it after the baseline and are not in your transcript (another session's, or a commit made before you started and re-dated); restore only your own change, not theirs."
~~~

7. command: `bash -c 'test -x hooks/scripts/writer-scope-gate.sh && bash tests/writer-scope-gate.test.sh | /usr/bin/grep -c "^FAIL"'`
   expect: 1
   `grep -c` prints `0` (no FAIL line) and exits 1. The file keeps mode 755 (hooks.json runs it directly).

8. file: `docs/trust-model.md`
   anchor: line matching `| 26 | A writing persona (lead-programmer, scribe, spec-master) ends its turn`
   indent: 0
   before:
~~~
is not checked. A missing transcript or a missing
~~~
   after:
~~~
is not checked. A path counts as named in a scribe's or spec-master's dispatch when it is a whole token of the prompt once quotes, brackets and backticks are split off and trailing sentence punctuation and a leading `./` are cut (a path that ends a sentence is named; `xREADME.md` and a same-named file in another directory are not). Also not checked: an Edit made through a symlink to a file in the repo (the link's target changes and is never attributed); a transcript with no timestamp and no commit line falls back to HEAD as its baseline (only fixtures look like this); a commit dated before the transcript's first timestamp (clock skew), which falls before the baseline. The baseline is a date lookup, so it can land too early: amending or rebasing a commit made before the session re-dates it past the start and moves the baseline back, so a path the writer touched only with an Edit shows the earlier unit's change and is blocked; and a writer that edited a file out of scope and then reverted it is blocked if another session committed to that file after the baseline, and its restore command would revert that commit. The block message lists, per path, the commits after the baseline that changed it and that no commit line of the transcript shows, so the writer restores only its own change. A missing transcript or a missing
~~~
   The `before:` text occurs once, inside row 26; the rest of the row is untouched, and the row stays one line.

9. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.209 to 0.31.210; derive it from HEAD at dispatch, queued units may have moved it). The bump is required: `--update` installs a changed hook script only when `pluginVersion` moves.

10. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Writer scope gate: a path that ends a sentence is named (rp-u15 fix 1, VERSION).** `hooks/scripts/writer-scope-gate.sh` gave `us_named_in` the raw prompt, so a scribe or spec-master whose dispatch named a file at the end of a sentence (`... eval/abtest/README.md. Changed API ...`) and committed it with `git commit -q` was blocked and told to revert the edit it was asked for. The gate now hands it one token per line, split at whitespace, quotes, backticks, brackets, `|`, `,`, `;` and `=`, with trailing `.,;:!?` and a leading `./` cut; inner dots stay, so `xREADME.md`, `README.md.bak` and a same-named file in another directory are still not named. A block now lists, per path, the commits after the baseline that changed it and that no commit line shows (another session's, or an earlier commit re-dated by an amend), because the restore command would revert them. docs/trust-model.md row 26 states the cases the gate does not check (an Edit through a file symlink, a transcript with no timestamp, clock skew, a baseline that lands too early). tests/writer-scope-gate.test.sh cases (aa) and (ab).
~~~
   Replace `VERSION` with the version the previous edit wrote.

11. command: `node bin/cli.js --update`
   expect: 0

12. command: `git add tests/writer-scope-gate.test.sh hooks/scripts/writer-scope-gate.sh docs/trust-model.md CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "fix(rp-u15): a path ending a sentence is named, and a block lists commits its restore would revert (rp-u15)"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified (spec-master may be writing docs; leave those alone), stage by the paths above and report it.

## Do NOT touch
- `hooks/hooks.json` (the registration is the operator's step O1; no agent identity may write it)
- `hooks/scripts/lib/unit-scope.sh`, `hooks/scripts/lib/state-access.sh` and `hooks/scripts/lib/agent-identity.sh` (the gate only sources them; the queued unit rp-u13 edits unit-scope.sh, so the tokenisation lives in the gate)
- `tests/validate.sh`, `tests/trust-model-bijection.test.js` and `tests/scope-libs.test.sh` (they run or read the gate and row 26 unchanged)
- `bin/`, `adapters/`, `agents/` and `templates/` (Claude-only gate; its block message is the instruction)
- `docs/plans/antislop-review-patches/contracts/rp-u15.md` (earlier contracts are not edited)
- `.claude/hooks/` and `.claude/agents/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/writer-scope-gate.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 4 (the `ptok` file is built but `us_named_in` keeps reading the raw prompt); 16 rows print FAIL and stdout is `1`. Delete ` s#^(\./)+##` from the `sed` line: 2 rows FAIL. Drop the `\047\042` pair from the `tr` set: 4 rows FAIL. Reduce the `tr` set to `[:space:]`: 8 rows FAIL. Replace `[ -z "$f" ] || echo` with `: || echo` in edit 6: 2 rows FAIL.
   proof: each change applied alone to a scratch copy of the finished change with a python replace or sed, FAIL counts as listed (16, 2, 4, 8, 2); the red 18 is the finished test file against the 65cd8b44 gate.
2. run: `bash -c 'bash tests/writer-scope-gate.test.sh | /usr/bin/grep -c "^OK   (aa) "'`
   exit: 0
   stdout: `56`
   mutation: delete the line `named_row 1 named ...` from the test; stdout is `54`.
3. run: `bash -c 'bash tests/writer-scope-gate.test.sh | /usr/bin/grep -c "^OK   (ab) "'`
   exit: 0
   stdout: `3`
   mutation: skip edit 6; two (ab) lines print FAIL and stdout is `1`.
4. run: `/usr/bin/grep -cF ptok hooks/scripts/writer-scope-gate.sh`
   exit: 0
   stdout: `3`
   mutation: skip edit 4; stdout is `2`.
5. run: `bash -c 'cmp hooks/scripts/writer-scope-gate.sh .claude/hooks/scripts/writer-scope-gate.sh && test -x hooks/scripts/writer-scope-gate.sh && test -x .claude/hooks/scripts/writer-scope-gate.sh && echo same'`
   exit: 0
   stdout: `same`
   mutation: skip edit 11 (`--update`); this fix bumps the version, so the installed copy stays the 65cd8b44 one, `cmp` reports a difference and the command exits 1.
6. run: `bash -c 't=$(grep "^| 26 |" docs/trust-model.md | tr -s " \n" " "); n=0; for p in "units st-u3, rp-u15" "a path that ends a sentence is named" "Also not checked: an Edit made through a symlink to a file in the repo" "a transcript with no timestamp and no commit line falls back to HEAD" "a commit dated before the transcript" "it can land too early" "its restore command would revert that commit" "that no commit line of the transcript shows"; do printf "%s" "$t" | grep -qF -- "$p" && n=$((n+1)); done; echo $n'`
   exit: 0
   stdout: `8`
   mutation: skip edit 8; stdout is `1`.
7. run: `bash -c 'node tests/trust-model-bijection.test.js >/dev/null 2>&1 && node tests/cli-hook-propagation.test.js >/dev/null 2>&1 && bash tests/harness-integrity-gate.test.sh >/dev/null 2>&1 && bash tests/state-access-constraints.test.sh >/dev/null 2>&1 && bash tests/scope-libs.test.sh >/dev/null 2>&1 && bash tests/abtest-arms.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete row 26 from `docs/trust-model.md`; trust-model-bijection C8.2 fails and stdout is `1`. abtest-arms reads `git archive HEAD`, so run this after edit 12.
8. run: `bash -c 'for c in $(git log --format="%H %s" 65cd8b44..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u15\): " | cut -d" " -f1); do git diff --name-only "$c~1..$c" -- . ":(exclude).claude"; done | LC_ALL=C sort -u | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md docs/trust-model.md hooks/scripts/writer-scope-gate.sh package.json tests/writer-scope-gate.test.sh `
   mutation: also edit `tests/validate.sh` in an rp-u15 commit; it joins the list.
9. run: `bash -c 'for c in $(git log --format="%H %s" 65cd8b44..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u15\): " | cut -d" " -f1); do git diff --name-only "$c~1..$c" -- hooks/hooks.json hooks/scripts/lib tests/validate.sh tests/trust-model-bijection.test.js tests/scope-libs.test.sh bin adapters agents templates docs/plans; done | wc -l'`
   exit: 0
   stdout: `0`
   mutation: register the gate in `hooks/hooks.json` in an rp-u15 commit; stdout is `1`.
10. run: `bash -c 'c=$(git log --format="%H %s" 65cd8b44..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u15\): " | cut -d" " -f1 | head -1); for f in package.json .claude-plugin/plugin.json; do p=$(git show "$c~1:$f" | /usr/bin/grep -m1 "\"version\"" | /usr/bin/grep -oE "[0-9]+\.[0-9]+\.[0-9]+"); n=$(git show "$c:$f" | /usr/bin/grep -m1 "\"version\"" | /usr/bin/grep -oE "[0-9]+\.[0-9]+\.[0-9]+"); [ "${p%.*}.$(( ${p##*.} + 1 ))" = "$n" ] && echo "$f ok"; done | paste -sd"|"'`
   exit: 0
   stdout: `package.json ok|.claude-plugin/plugin.json ok`
   mutation: bump `.claude-plugin/plugin.json` only; stdout is `.claude-plugin/plugin.json ok`.
11. run: `node -e "const v=require('./package.json').version,w=require('./.claude-plugin/plugin.json').version,t=require('fs').readFileSync('CHANGELOG.md','utf8');process.exit(v===w&&t.includes('(rp-u15 fix 1, '+v+')')?0:1)" && echo version-sync: ok`
   exit: 0
   stdout: `version-sync: ok`
   mutation: bump `.claude-plugin/plugin.json` only, or leave `VERSION` in the CHANGELOG line; the exit is 1 with empty stdout.
12. run: `bash -c 'tr "\n" " " < CHANGELOG.md | tr -s " " | /usr/bin/grep -cF "a path that ends a sentence is named"'`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; stdout is `0` and the exit is 1.
13. run: `bash -c 'e=$(git log --format="%H %s" 65cd8b44..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u15\): " | cut -d" " -f1 | head -1); git log --format=%s "$e"..HEAD -- hooks/scripts/writer-scope-gate.sh tests/writer-scope-gate.test.sh docs/trust-model.md | /usr/bin/grep -vcE "^[a-z]+\(rp-u15\): "'`
   exit: 1
   stdout: `0`
   mutation: make a later commit with another subject that touches `docs/trust-model.md`; stdout is `1` and the exit is 0.
14. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/writer-scope-gate.test.sh; validate.sh exits 1 and stdout is `1`.
15. run: `bash -c 'git status --porcelain --untracked-files=no -- hooks tests .claude/hooks .claude/agents CHANGELOG.md package.json .claude-plugin docs/trust-model.md'`
   exit: 0
   stdout: empty
   mutation: leave edit 11 (`--update`) out of the commit; a `.claude/` path shows as modified and stdout is not empty.

## Pre-resolved context
tdd: yes tests/writer-scope-gate.test.sh; edit 1 adds cases (aa) rows 1 to 28 for scribe and spec-master and (ab); edit 2 shows them red (`18`) before edits 3 to 6.
blast-radius: hooks/scripts/writer-scope-gate.sh:141 (the `us_section` line, edit 3), :165 (`us_named_in`, edit 4), :181 (`viol=()`, edit 5), :206 (the `else echo "  rm --` line, edit 6); tests/writer-scope-gate.test.sh:190 (end of case (z)); docs/trust-model.md:64 (row 26); hooks/scripts/lib/unit-scope.sh:105-111 (`us_named_in`, read and unchanged; `us_classify` still calls it on the criteria and fail-record files at :162-163). Line numbers are at 65cd8b44.
order: no dependency on the queued units rp-u10, rp-u12, rp-u7, rp-u4, rp-u5, rp-u6, rp-u13, rp-u14 or rp-s1 (checked by grep of their contracts: none edits `hooks/scripts/writer-scope-gate.sh`, `tests/writer-scope-gate.test.sh` or `docs/trust-model.md`). rp-u13 edits `hooks/scripts/lib/unit-scope.sh` only (`us_section`, `us_exclusions`) and names the gate and its test in its Do NOT touch; this fix sits beside it and does not edit that library, and none of the 28 rows holds a `## Do NOT touch` or `## Affected files` heading, so rp-u13's section grammar cannot change a row. The fix shares only the three stamp files (`CHANGELOG.md`, `package.json`, `.claude-plugin/plugin.json`) with every queued unit: each inserts after `## [Unreleased]` and sets HEAD plus one, so run it serial with the others in any order and derive the version at dispatch; do not copy 0.31.210.
tokenisation: the gate hands `us_named_in` the file `$W/ptok`: the prompt with every character of `[:space:]`, backtick, `(`, `)`, `[`, `]`, `{`, `}`, `<`, `>`, `|`, `,`, `;`, `=`, `'` and `"` turned into a newline, then, on each line, trailing `.`, `,`, `;`, `:`, `!` and `?` removed until none is left and a leading `./` removed. Inner dots stay. `path:12` and `path#L12` need no rule: `:` and `#` already end a path token in `us_named_in`, and rows 10 and 13 pin that. A path inside a markdown link or a code fence is a token of its own. `xREADME.md`, `README.md.bak`, `README.md/more` and a same-named file in another directory stay unnamed because `us_named_in` still demands a non-path character on both sides. Only scribe and spec-master read it (the lead-programmer branch of `in_scope` does not use the prompt copy), so lead-programmer's decisions do not change.
baseline-decision: the two cases the reviewer left to a decision are documented in row 26 (edit 8) and warned about at block time (edit 6), not made to pass: a baseline that lands too early (an amended or rebased earlier commit re-dated past the start) still blocks a writer that only Edited the path, and a writer that edited a file out of scope then reverted it is still blocked when another session committed to it. The block message adds, per path, `commit(s) <short shas> changed it after the baseline and are not in your transcript`, the shas being the commits of `<baseline>..HEAD` that touch the path and that no `[<branch> <sha>]` line of the transcript shows, so the writer restores only its own change. Rejected: moving the baseline to the merge-base of the transcript's visible commits alone (it would let a committed out-of-scope edit with no commit line through, the rp-u15 G1 case) and blaming nothing when a foreign commit exists (it would reopen the same hole).
not-in-this-fix: the optional items of the FAIL record (none beyond the above). Row 26's three uncovered cases (an Edit through an in-repo file symlink, a transcript with no timestamp and no commit line, a commit dated before the first timestamp) are text only, with no gate change.
version: .claude-plugin/plugin.json and package.json read 0.31.209 at 65cd8b44; edit 9 adds one (expected 0.31.210 if no queued unit has landed first).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: fix(rp-u15): a path ending a sentence is named, and a block lists commits its restore would revert (rp-u15)
fix-of: 2026-10-22T17:25:51Z
diagnosis: none
review-packet:
~~~
unit: rp-u15
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
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written (a `before:` payload not found verbatim once, a `--update` refusal, a gate block), STOP and report a spec gap; do not improvise.
