Unit: st-u4

## Objective
Fix round 2 for st-u4 (fix-of: 2026-10-22T15:37:01Z, the latest FAIL block; the haiku tier is spent, the implementer runs on sonnet). `bin/unit-size.sh` still prints `lane: small` for a bare `.claude/hooks` entry (script and contract mode), because the sensitive anchors need a trailing slash and the existing-directory check never ran on bookkeeping entries. The two loops that judge entries disagreed; this fix replaces all four loops with ONE `judge_entry` function applied to every raw entry: an unsafe path, glob or trailing slash is `full ... unmeasurable`; the sensitive class is tried on the entry and on the entry plus a slash (`full ... sensitive`), as `us_listed` treats an entry as a directory prefix; an existing directory outside the free zones (`.claude/agents/*`, `.claude/bin/*`, `docs/plans/*`) is `full ... unmeasurable`; an unmeasurable entry still wins over a sensitive one. `tests/unit-size.test.sh` gains a matrix with a bare-directory, directory-with-slash and file row for every `SENSITIVE_PATHS` entry in script and contract mode, plus free-zone rows. `agents/orchestrator.md` is unchanged: its "anything it cannot measure prints `full`" is true again. Version: HEAD plus one at dispatch (expected 0.31.206 to 0.31.207); mirrors refreshed.

## Retrieval
Fast path, no tracker issue. This file is the second fix contract of record for the same `Unit: st-u4`; the original contract is `docs/plans/antislop-structural/contracts/st-u4.md` (commit 7231a42e, version 0.31.205) and the first fix contract is `docs/plans/antislop-structural/contracts/st-u4-fix1.md` (landed as 636ef3e5, version 0.31.206); both stay unchanged. Spec: `docs/plans/antislop-structural/spec.md`, "Step 4 (st-u4)".

## Affected files
- `tests/unit-size.test.sh` (anchor: line matching `is "(m) a newline in an argument"`)
- `bin/unit-size.sh` (anchors: line matching `grep -v '^$' "$W/raw" | sort -u > "$W/all" || true`; line matching `[ -d "$p" ] && emit full "$n" unmeasurable`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- generated only, by `node bin/cli.js --update`: `.claude/bin/unit-size.sh`, `.claude/agents/*.md`, `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits

1. file: `tests/unit-size.test.sh`
   anchor: line matching `is "(m) a newline in an argument"`
   indent: 0
   insert-after:
~~~
# (n) st-u4 fix 2: one judge for every entry. A directory prefix is sensitive when the entry or the entry plus a
# slash is in the class (us_listed treats an entry as a directory prefix), and an existing directory outside the
# free zones is unmeasurable.
is "(n) a bare .claude/hooks dir" 'lane: full files=1 reason=sensitive' u1 -- .claude/hooks src/a.js
is "(n) a bare .claude/agents dir is not the free zone" 'lane: full files=1 reason=sensitive' u1 -- .claude/agents src/a.js
is "(n) a bare hooks dir" 'lane: full files=2 reason=sensitive' u1 -- hooks src/a.js
is "(n) a bare .claude dir" 'lane: full files=2 reason=unmeasurable' u1 -- .claude src/a.js
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
~~~
   The block sits directly after the existing (m) rows and before the `cat > docs/plans/p/contracts/u2.md` line; nothing else in the file changes.

2. command: `bash tests/unit-size.test.sh`
   expect: 1
   The red step: the script still lets a bare `.claude/hooks`, `.claude/agents`, `.claude-plugin` and `agents` through, so eight (n) lines print FAIL.

3. file: `bin/unit-size.sh`
   anchor: line matching `grep -v '^$' "$W/raw" | sort -u > "$W/all" || true`
   indent: 0
   before:
~~~
# Bookkeeping entries are still judged: a `..` segment or glob can leave .claude/ or docs/plans/, and a
# hand-edited .claude/hooks or .claude settings entry is sensitive. Only .claude/agents/ copies stay free.
grep -v '^$' "$W/raw" | sort -u > "$W/all" || true
while IFS= read -r p; do
  us_safe_path "$p" || emit full "$n" unmeasurable
  case "$p" in *[*?[]*|*/) emit full "$n" unmeasurable ;; esac
done < "$W/all"
while IFS= read -r p; do
  case "$p" in
    .claude/agents/*) ;;
    .claude/*) touches_sensitive_path "$p" && emit full "$n" sensitive ;;
  esac
done < "$W/all"
~~~
   after:
~~~
# ONE judge for every raw entry, bookkeeping ones included, so the loops cannot disagree (st-u4 fix 2).
# judge_entry <path>: 0 = measurable and clean, 1 = unmeasurable, 2 = sensitive. An entry is a directory
# prefix (us_listed), so the sensitive class is tried on the entry and on the entry plus a slash, and an
# existing directory outside the free zones is unmeasurable. Free zones: generated .claude/agents/ and
# .claude/bin/ copies and the docs/plans/ plan itself.
judge_entry() {
  local p="$1"
  us_safe_path "$p" || return 1
  case "$p" in *[*?[]*|*/) return 1 ;; esac
  case "$p" in .claude/agents/*|.claude/bin/*|docs/plans/*) return 0 ;; esac
  touches_sensitive_path "$p" && return 2
  touches_sensitive_path "$p/" && return 2
  [ -d "$p" ] && return 1
  return 0
}
grep -v '^$' "$W/raw" | sort -u > "$W/all" || true
sens=0
while IFS= read -r p; do
  judge_entry "$p"; rc=$?
  [ "$rc" = 1 ] && emit full "$n" unmeasurable
  [ "$rc" = 2 ] && sens=1
done < "$W/all"
[ "$sens" = 1 ] && emit full "$n" sensitive
~~~
   The line `[ "$n" -gt 0 ] || emit full 0 empty` directly below stays.

4. file: `bin/unit-size.sh`
   anchor: line matching `[ -d "$p" ] && emit full "$n" unmeasurable`
   indent: 0
   delete:
~~~
while IFS= read -r p; do
  # An entry the sensitive-path anchors cannot judge (`./hooks/x.sh`, `src//a.js`, `/x`) is unmeasurable.
  us_safe_path "$p" || emit full "$n" unmeasurable
  case "$p" in *[*?[]*|*/) emit full "$n" unmeasurable ;; esac
  [ -d "$p" ] && emit full "$n" unmeasurable
done < "$W/entries"
while IFS= read -r p; do
  touches_sensitive_path "$p" && emit full "$n" sensitive
done < "$W/entries"
~~~
   These nine lines sit between `[ "$n" -gt 0 ] || emit full 0 empty` and `[ -f "$dot/reviewed/$unit.fail" ] && emit full "$n" fail-record`; after the delete the second follows the first directly.

5. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.206 to 0.31.207; the new version is HEAD's plus one when this unit runs).

6. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Lane routing: one judge for every entry (st-u4 fix 2, VERSION).** `bin/unit-size.sh` still let a bare `.claude/hooks` entry through as small: the sensitive anchors (`^\.claude/hooks/`) need the trailing slash, and the existing-directory check ran only on entries outside `.claude/` and `docs/plans/`. One `judge_entry` function now judges every raw entry the same way: an unsafe path, glob or trailing slash is full (unmeasurable); the sensitive class is tried on the entry and on the entry plus a slash, so a bare `.claude/hooks`, `.claude-plugin`, `agents` or `adapters/cursor/hooks` is full (sensitive), because `us_listed` treats an entry as a directory prefix; an existing directory outside the free zones (`.claude/agents/*`, `.claude/bin/*`, `docs/plans/*`) is full (unmeasurable). The four loops become one, and an unmeasurable entry still wins over a sensitive one. tests/unit-size.test.sh gains a matrix with a bare-directory, directory-with-slash and file row for every `SENSITIVE_PATHS` entry in script and contract mode, and the free-zone rows; no contract under docs/plans changes lane or reason against 0.31.206.
~~~
   Replace `VERSION` with the version that edit 5 wrote.

7. command: `node bin/cli.js --update`
   expect: 0

8. command: `bash tests/unit-size.test.sh`
   expect: 0

9. command: `git add bin/unit-size.sh tests/unit-size.test.sh CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "fix(st-u4): one judge for every lane entry, bare sensitive directories and existing directories are full (st-u4)"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it. Stage by path only, never `git add -A`.

## Do NOT touch
- `hooks/hooks.json`, `hooks/` and `.claude/hooks/` (reviewer-tier.sh among them; criterion 14)
- `hooks/scripts/lib/sensitive-paths.sh` and `hooks/scripts/lib/unit-scope.sh` (st-u1's library: `us_entries` drops a bare `hooks` token by design and the case-sensitive regexes stay; both are noted, not fixed here)
- `bin/cli.js`, `tests/bin-helpers-scaffold.test.sh` and `tests/validate.sh` (the helper list, the scaffold list and the validate.sh block stay as st-u4 left them; criterion 14)
- `agents/` and `templates/` (the orchestrator prose "anything it cannot measure prints `full`" is true again and stays; criterion 14)
- `adapters/` (the codex and cursor ports keep today's pipeline; criterion 14)
- `docs/plans/antislop-structural/contracts/st-u4.md` and `docs/plans/antislop-structural/contracts/st-u4-fix1.md` (earlier contracts are not edited)
- `.claude/agents/` and `.claude/bin/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/unit-size.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 3 (the script keeps the old loops); the (n) rows for a bare `.claude/hooks`, `.claude-plugin` and `agents` print FAIL and stdout is `1`. Delete the line `  touches_sensitive_path "$p/" && return 2` instead: 8 rows print FAIL, stdout `1`. Delete the line `  [ -d "$p" ] && return 1` instead: 3 rows print FAIL, stdout `1`. Delete the line `  case "$p" in .claude/agents/*|.claude/bin/*|docs/plans/*) return 0 ;; esac` instead: 6 rows print FAIL, stdout `1`.
   proof: each deletion applied alone with sed to a scratch worktree of the finished change; stdout `1` each time, with the FAIL counts 8, 3 and 6.

2. run: `bash -c 'bash tests/unit-size.test.sh | /usr/bin/grep -c "^OK   (n) row "'`
   exit: 0
   stdout: `54`
   mutation: delete the line holding `mx_full "(n) row $i bare dir"` from tests/unit-size.test.sh; stdout is `46`.
   proof: sed deletion in a scratch worktree of the finished change; stdout `46`.

3. run: `cmp bin/unit-size.sh .claude/bin/unit-size.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 7; `--update` leaves the old installed script and cmp prints `differ` and exits 1.
   proof: scratch worktree of the finished change with `.claude/bin/unit-size.sh` restored from HEAD; cmp exit 1.

4. run: `bash -c 'bash tests/bin-helpers-scaffold.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the `'unit-size.sh'` entry from BIN_HELPER_FILES in bin/cli.js; case (a) fails and stdout is `1`.
   proof: scratch worktree of the finished change with the entry deleted; stdout `1`.

5. run: `bash -c 'd=$(mktemp -d); for a in .claude/hooks .claude/agents hooks .claude-plugin agents adapters/cursor/hooks .claude; do CLAUDE_PROJECT_DIR=$d bash .claude/bin/unit-size.sh zz -- $a src/a.js; done | paste -sd"|"'`
   exit: 0
   stdout: `lane: full files=1 reason=sensitive|lane: full files=1 reason=sensitive|lane: full files=2 reason=sensitive|lane: full files=2 reason=sensitive|lane: full files=2 reason=sensitive|lane: full files=2 reason=sensitive|lane: full files=2 reason=unmeasurable`
   mutation: skip edit 3 and edit 4 and copy the old script over `.claude/bin/unit-size.sh`; the first field becomes `lane: small files=1 reason=paths`.
   proof: scratch worktree with bin/unit-size.sh restored from HEAD and copied to `.claude/bin/`; the first and second fields read `lane: small files=1 reason=paths`.

6. run: `bash -c 'd=$(mktemp -d); printf "## Affected files\n- \140.claude/hooks\140\n- \140src/a.js\140\n" > $d/c.md; CLAUDE_PROJECT_DIR=$d bash .claude/bin/unit-size.sh zz --contract $d/c.md'`
   exit: 0
   stdout: `lane: full files=1 reason=sensitive`
   mutation: skip edit 3 and edit 4 with the old script copied over `.claude/bin/unit-size.sh`; it prints `lane: small files=1 reason=contract`.
   proof: scratch worktree with the old script copied to `.claude/bin/`; prints `lane: small files=1 reason=contract`.

7. run: `bash -c 'd=$(mktemp -d); export CLAUDE_PROJECT_DIR=$d; u=.claude/bin/unit-size.sh; { bash $u zz -- .claude/agents/x/y.md src/a.js; bash $u zz -- .claude/bin/x.sh docs/plans/p/s.md src/a.js; bash $u zz -- docs/plans/antislop-structural src/a.js test/a.test.js; } | paste -sd"|"'`
   exit: 0
   stdout: `lane: small files=1 reason=paths|lane: small files=1 reason=paths|lane: small files=2 reason=paths`
   mutation: delete the line `  case "$p" in .claude/agents/*|.claude/bin/*|docs/plans/*) return 0 ;; esac` from bin/unit-size.sh and copy it over `.claude/bin/unit-size.sh`; the first field becomes `lane: full files=1 reason=sensitive` and the third `lane: full files=2 reason=unmeasurable`.
   proof: the same deletion in a scratch worktree of the finished change with the script copied to `.claude/bin/`.

8. run: `/usr/bin/grep -c 'done < "$W/' bin/unit-size.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; the two old loops over `$W/entries` stay and stdout is `3`.
   proof: scratch worktree of the finished change with the nine deleted lines restored; stdout `3`.

9. run: `bash -c 'd=$(mktemp -d); mkdir -p $d/old/bin; git show 636ef3e5:bin/unit-size.sh > $d/old/bin/unit-size.sh; ln -s "$PWD/hooks" $d/old/hooks; n=0; for f in docs/plans/*/contracts/*.md; do a=$(CLAUDE_PROJECT_DIR=$d bash $d/old/bin/unit-size.sh zz --contract $f); b=$(CLAUDE_PROJECT_DIR=$d bash bin/unit-size.sh zz --contract $f); [ "$a" = "$b" ] || n=$((n+1)); done; echo $n'`
   exit: 0
   stdout: `0`
   mutation: delete the line `  touches_sensitive_path "$p" && return 2` from bin/unit-size.sh; the sensitive contracts print medium or small and stdout is `10`.
   proof: sed deletion in a scratch worktree of the finished change; stdout `10`. The unmutated run over the 135 contracts at 636ef3e5 prints `0`: no line (lane, files or reason) differs from the 0.31.206 script.

10. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'`
    exit: 0
    stdout: `0`
    mutation: put `exit 1` as line 2 of tests/unit-size.test.sh; the validate.sh block fails and stdout is `1`.
    proof: `grep -c 'bash tests/unit-size.test.sh' tests/validate.sh` prints `1` (line 805), and criterion 1 with the same mutation prints `1`; the full validate.sh run of the finished change exited 0.

11. run: `bash -c 'git log --format="%H %s" 636ef3e5..HEAD | /usr/bin/grep -cE "^[0-9a-f]+ [a-z]+\(st-u4\): "'`
    exit: 0
    stdout: `1`
    mutation: land the change as two commits with the subject scope `(st-u4)`; stdout is `2`.
    proof: scratch worktree, the change split into two commits; stdout `2`.

12. run: `bash -c 'for c in $(git log --format="%H %s" 636ef3e5..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(st-u4\): " | cut -d" " -f1); do git diff --name-only "$c~1..$c"; done | /usr/bin/grep -vE "^\.claude/" | /usr/bin/grep -vcE "^(bin/unit-size\.sh|tests/unit-size\.test\.sh|CHANGELOG\.md|package\.json|\.claude-plugin/plugin\.json)$"'`
    exit: 1
    stdout: `0`
    mutation: in the fix commit also append a line to agents/orchestrator.md; stdout is `1` and the exit is 0.
    proof: scratch worktree, fix commit with a line appended to agents/orchestrator.md; exit 0, stdout `1`.

13. run: `bash -c 'for c in $(git log --format="%H %s" 636ef3e5..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(st-u4\): " | cut -d" " -f1); do git diff --name-only "$c~1..$c"; done | /usr/bin/grep -E "^\.claude/" | /usr/bin/grep -vcE "^\.claude/(agents/|bin/unit-size\.sh$|persona|protocol-digest\.md$)"'`
    exit: 1
    stdout: `0`
    mutation: in the fix commit also change a file under `.claude/hooks/`; stdout is `1` and the exit is 0.
    proof: scratch worktree, fix commit with a line appended to a file under `.claude/hooks/scripts/`; exit 0, stdout `1`.

14. run: `bash -c 'e=$(git log --format="%H %s" 636ef3e5..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(st-u4\): " | cut -d" " -f1 | head -1); git log --format=%s "$e"..HEAD -- bin/unit-size.sh tests/unit-size.test.sh | /usr/bin/grep -vcE "^[a-z]+\(st-u4\): "'`
    exit: 1
    stdout: `0`
    mutation: make a later commit with another subject that touches tests/unit-size.test.sh; stdout is `1` and the exit is 0.
    proof: scratch worktree, fix commit then an untagged commit appending to tests/unit-size.test.sh; exit 0, stdout `1`.

15. run: `bash -c 'c=$(git log --format="%H %s" 636ef3e5..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(st-u4\): " | cut -d" " -f1 | head -1); for f in package.json .claude-plugin/plugin.json; do p=$(git show "$c~1:$f" | /usr/bin/grep -m1 "\"version\"" | /usr/bin/grep -oE "[0-9]+\.[0-9]+\.[0-9]+"); n=$(git show "$c:$f" | /usr/bin/grep -m1 "\"version\"" | /usr/bin/grep -oE "[0-9]+\.[0-9]+\.[0-9]+"); [ "${p%.*}.$(( ${p##*.} + 1 ))" = "$n" ] && echo "$f ok"; done | paste -sd"|"'`
    exit: 0
    stdout: `package.json ok|.claude-plugin/plugin.json ok`
    mutation: skip edit 5; nothing prints and stdout is empty.
    proof: scratch worktree of the finished change committed without the bump; stdout empty.

16. run: `node -e "const v=require('./package.json').version,w=require('./.claude-plugin/plugin.json').version,t=require('fs').readFileSync('CHANGELOG.md','utf8');process.exit(v===w&&t.includes('(st-u4 fix 2, '+v+')')?0:1)" && echo version-sync: ok`
    exit: 0
    stdout: `version-sync: ok`
    mutation: run edit 5 on `.claude-plugin/plugin.json` only, or leave `VERSION` in the CHANGELOG line; the exit is 1 with empty stdout.
    proof: scratch worktree, package.json restored to HEAD; exit 1, empty stdout.

17. run: `bash -c 'tr "\n" " " < CHANGELOG.md | tr -s " " | /usr/bin/grep -cF "the sensitive class is tried on the entry and on the entry plus a slash"'`
    exit: 0
    stdout: `1`
    mutation: skip edit 6; stdout is `0` and the exit is 1.
    proof: scratch worktree of the finished change with the CHANGELOG entry removed; stdout `0`.

18. run: `bash -c 'for f in agents/orchestrator.md .claude/agents/orchestrator.md; do tr "\n" " " < $f | tr -s " " | /usr/bin/grep -cF "anything it cannot measure prints"; done | paste -sd,'`
    exit: 0
    stdout: `1,1`
    mutation: reword `anything it cannot measure prints` in agents/orchestrator.md and rerun `node bin/cli.js --update`; stdout is `0,0`.
    proof: scratch worktree with the rewording and the update run; stdout `0,0`.

## Pre-resolved context
tdd: yes tests/unit-size.test.sh; edit 1 adds the failing rows and edit 2 runs them red.
blast-radius: bin/unit-size.sh:44-56 (the bookkeeping judge and its two loops, edit 3), bin/unit-size.sh:58-66 (the two loops on the filtered entries, edit 4; the unmeasurable `-d` check at :62 moves into `judge_entry`), tests/unit-size.test.sh:58 (the last (m) row), hooks/scripts/lib/sensitive-paths.sh:11-24 and hooks/scripts/lib/unit-scope.sh:75-80 (sourced, unchanged). Callers: bin/review-precheck.sh:113 copies `.claude/bookkeeping/<unit>.scope` (the filtered entries, unchanged by this fix), bin/cli.js:656 BIN_HELPER_FILES installs the script, tests/validate.sh:804-808 runs the test. Line numbers are at 636ef3e5.
order: no dependency on the queued units rp-u15, rp-u10, rp-u12, rp-u7, rp-u4, rp-u5, rp-u6, rp-u13, rp-u14 or rp-s1: none edits bin/unit-size.sh or tests/unit-size.test.sh (checked by grep of their contracts' Affected files), and unlike fix 1 this fix does not edit agents/orchestrator.md, so it does not touch rp-u5's file; rp-u15 edits hooks/scripts/writer-scope-gate.sh and docs/trust-model.md, rp-u6 edits tests/validate.sh near the unit-size echo line (different file from this fix's). It shares only the three stamp files with every queued unit: all insert after `## [Unreleased]` in CHANGELOG.md and each sets HEAD plus one, so run it serial with the others (any order) and derive the version at dispatch; do not copy 0.31.207. rp-s1 (glossary) names the unit-size script but describes no lane rule this fix changes.
lane-rules: the check order is now: no input, a leading-dash or newline `--` argument (files=0 unmeasurable), then over every raw entry `judge_entry` (an unsafe path, glob or trailing slash is unmeasurable; free-zone entries `.claude/agents/*`, `.claude/bin/*`, `docs/plans/*` are clean; the sensitive class on the entry and on the entry plus a slash is sensitive; an existing directory is unmeasurable), any unmeasurable entry wins, then sensitive, then empty, then the FAIL record, size and count checks as before. The scope file still holds the filtered entries. A bare zone directory (`.claude/agents`, `docs/plans`) is not free: `.claude/agents` is sensitive, and `docs/plans` is an existing directory.
consequence: reasons only: `hooks src/a.js` now prints `reason=sensitive` where it printed `reason=unmeasurable`. Measured over the 135 contracts under docs/plans, no line differs from the 0.31.206 script, and against the original st-u4 script (7231a42e) 28 change reason and none changes lane.
not-in-this-fix: the reviewer's two optional notes. `us_entries` drops a backticked token with no `/` and no `.`, so a contract listing a bare `hooks` prints the lane of the remaining entries (precheck would flag any hooks/ edit as scope: out); the matrix therefore asserts contract mode only for forms holding a `/` or a `.`. The sensitive regexes are case-sensitive (`HOOKS/x.sh` on a case-insensitive filesystem). Both are follow-ups owned by the shared library, which this fix does not touch.
commit-message: fix(st-u4): one judge for every lane entry, bare sensitive directories and existing directories are full (st-u4)
fix-of: 2026-10-22T15:37:01Z
diagnosis: none
review-packet:
~~~
unit: st-u4
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
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
criterion 18: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written (a `before:` payload not found verbatim once, a `--update` refusal, a gate block), STOP and report a spec gap; do not improvise.
