Unit: st-u4

## Objective
Fix round 3 for st-u4 (fix-of: 2026-10-22T16:10:33Z; the implementer runs on sonnet). `bin/unit-size.sh` prints `lane: small` for a directory that does not exist yet under a sensitive pattern with an open tail (`adapters/windsurf`, `templates/persona-protocol-v2`, `.claude/settings.d`), in script and contract mode. Root cause of all three FAILs: an entry, which `us_listed` treats as a directory prefix, was tested against regexes written for files. The fix is structural: every entry that is not an existing regular file is judged by what could sit beneath it. `sp_head` reads the literal head of each `SENSITIVE_PATHS` pattern (the text before its first regex metacharacter) and `under_sensitive` marks the entry sensitive when it is an ancestor of a head or when a head is a prefix of the entry and that pattern's tail is open; a pattern it cannot read makes every such entry sensitive. Size side: a not-yet-existing plain name with no dot (`src/newmodule`) is a new directory and is `full ... unmeasurable`; `src/new.js` stays one file. Contract mode also rejects an option-like entry, as script mode does. `tests/unit-size.test.sh` gains block (o) with the reproductions and an ancestor test generated from the library: one witness per pattern, every proper ancestor bare and with a slash asserted `full` in script and contract mode, with a count guard. Version: HEAD plus one at dispatch (expected 0.31.207 to 0.31.208); mirrors refreshed.

## Retrieval
Fast path, no tracker issue. This file is the third fix contract of record for the same `Unit: st-u4`; the original contract is `docs/plans/antislop-structural/contracts/st-u4.md` (commit 7231a42e, version 0.31.205), the first fix contract is `st-u4-fix1.md` (landed as 636ef3e5, 0.31.206) and the second is `st-u4-fix2.md` (landed as 5cb583c1, 0.31.207); all three stay unchanged. Spec: `docs/plans/antislop-structural/spec.md`, "Step 4 (st-u4)".

## Affected files
- `tests/unit-size.test.sh` (anchors: line matching `is "(a) four is still small"`; line matching `is "(b) five is medium"`; line matching `is "(b) ten is medium"`; line matching `is "(c) eleven is full"`; line matching `is "(h) only bookkeeping entries"`; line matching `is "(n) a bare .claude dir"`; line matching `cat > docs/plans/p/contracts/u2.md << 'MD'`)
- `bin/unit-size.sh` (anchor: line matching `judge_entry() {`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- generated only, by `node bin/cli.js --update`: `.claude/bin/unit-size.sh`, `.claude/agents/*.md`, `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits

1. file: `tests/unit-size.test.sh`
   anchor: line matching `is "(a) four is still small"`
   indent: 0
   before:
~~~
is "(a) four is still small" 'lane: small files=4 reason=paths' u1 -- a b c d
~~~
   after:
~~~
is "(a) four is still small" 'lane: small files=4 reason=paths' u1 -- a.js b.js c.js d.js
~~~

2. file: `tests/unit-size.test.sh`
   anchor: line matching `is "(b) five is medium"`
   indent: 0
   before:
~~~
is "(b) five is medium" 'lane: medium files=5 reason=paths' u1 -- a b c d e
~~~
   after:
~~~
is "(b) five is medium" 'lane: medium files=5 reason=paths' u1 -- a.js b.js c.js d.js e.js
~~~

3. file: `tests/unit-size.test.sh`
   anchor: line matching `is "(b) ten is medium"`
   indent: 0
   before:
~~~
is "(b) ten is medium" 'lane: medium files=10 reason=paths' u1 -- a b c d e f g h i j
~~~
   after:
~~~
is "(b) ten is medium" 'lane: medium files=10 reason=paths' u1 -- a.js b.js c.js d.js e.js f.js g.js h.js i.js j.js
~~~

4. file: `tests/unit-size.test.sh`
   anchor: line matching `is "(c) eleven is full"`
   indent: 0
   before:
~~~
is "(c) eleven is full" 'lane: full files=11 reason=size' u1 -- a b c d e f g h i j k
~~~
   after:
~~~
is "(c) eleven is full" 'lane: full files=11 reason=size' u1 -- a.js b.js c.js d.js e.js f.js g.js h.js i.js j.js k.js
~~~

5. file: `tests/unit-size.test.sh`
   anchor: line matching `is "(h) only bookkeeping entries"`
   indent: 0
   before:
~~~
is "(h) only bookkeeping entries" 'lane: full files=0 reason=empty' u2 -- .claude/x docs/plans/y
~~~
   after:
~~~
is "(h) only bookkeeping entries" 'lane: full files=0 reason=empty' u2 -- .claude/bin/x docs/plans/y
~~~

6. file: `tests/unit-size.test.sh`
   anchor: line matching `is "(n) a bare .claude dir"`
   indent: 0
   before:
~~~
is "(n) a bare .claude dir" 'lane: full files=2 reason=unmeasurable' u1 -- .claude src/a.js
~~~
   after:
~~~
is "(n) a bare .claude dir" 'lane: full files=2 reason=sensitive' u1 -- .claude src/a.js
~~~
   The row keeps its line; only the expected reason changes, because a bare `.claude` is now an ancestor of the `.claude/hooks/` head and is sensitive before the existing-directory check runs.

7. file: `tests/unit-size.test.sh`
   anchor: line matching `cat > docs/plans/p/contracts/u2.md << 'MD'`
   indent: 0
   before:
~~~
cat > docs/plans/p/contracts/u2.md << 'MD'
~~~
   after:
~~~
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
~~~
   The new block (o) sits directly before the existing `cat > docs/plans/p/contracts/u2.md` line, after the (n) free-zone loop; the `cat` line itself is kept.

8. command: `bash tests/unit-size.test.sh`
   expect: 1
   The red step: `bin/unit-size.sh` is not yet changed, so 23 lines print FAIL (the (n) bare `.claude` row and the (o) new-directory, bare-directory, contract-mode and ancestor rows).

9. file: `bin/unit-size.sh`
   anchor: line matching `judge_entry() {`
   indent: 0
   before:
~~~
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
~~~
   after:
~~~
# sp_head <pattern>: reads one SENSITIVE_PATHS regex. Sets SP_HEAD to its literal head (the text between the
# leading ^ and the first regex metacharacter; a backslash-escaped character counts as literal; a character
# followed by * + ? or { is not literal) and SP_OPEN to 0 only when the rest of the pattern is exactly `$`
# (the pattern names one path), else 1 (a path beneath the head may match). Returns 1 for a pattern it cannot
# read (no leading ^, or any |): the caller then treats every directory-like entry as sensitive.
sp_head() {
  local re="$1" c n
  SP_HEAD=""; SP_OPEN=1
  case "$re" in '^'*) re="${re#^}" ;; *) return 1 ;; esac
  case "$re" in *'|'*) return 1 ;; esac
  while [ -n "$re" ]; do
    c="${re:0:1}"
    case "$c" in
      '\') SP_HEAD+="${re:1:1}"; re="${re:2}" ;;
      '.'|'*'|'+'|'?'|'['|']'|'('|')'|'{'|'}'|'$'|'^') break ;;
      *) n="${re:1:1}"
         case "$n" in '*'|'+'|'?'|'{') break ;; esac
         SP_HEAD+="$c"; re="${re:1}" ;;
    esac
  done
  [ "$re" = '$' ] && SP_OPEN=0
  return 0
}
# under_sensitive <entry>: exit 0 when some path beneath <entry>/ could be in the sensitive class: the entry is
# an ancestor of a pattern's head (`.claude` of `.claude/hooks/`, `bin` of `bin/cli.js`), or a pattern with an
# open tail has a head that is a prefix of <entry>/ (`adapters/.*hooks` and `adapters/windsurf`).
under_sensitive() {
  local e="$1/" re
  for re in "${SENSITIVE_PATHS[@]}"; do
    sp_head "$re" || return 0
    case "$SP_HEAD" in "$e"*) return 0 ;; esac
    if [ "$SP_OPEN" = 1 ]; then case "$e" in "$SP_HEAD"*) return 0 ;; esac; fi
  done
  return 1
}
# judge_entry <path>: 0 = measurable and clean, 1 = unmeasurable, 2 = sensitive. An entry is a directory
# prefix (us_listed: the entry, or anything beneath entry/), so every entry that is not an existing regular
# file is judged by what could sit beneath it, never as a file (st-u4 fix 3). Sensitive: the class matches the
# entry or entry/, or under_sensitive. Unmeasurable: an unsafe path, glob, option-like or trailing-slash entry,
# an existing directory, and a not-yet-existing plain name with no dot (a new directory is a bigger task than
# small). Free zones: generated .claude/agents/ and .claude/bin/ copies and the docs/plans/ plan itself.
judge_entry() {
  local p="$1"
  us_safe_path "$p" || return 1
  case "$p" in *[*?[]*|*/|-*) return 1 ;; esac
  case "$p" in .claude/agents/*|.claude/bin/*|docs/plans/*) return 0 ;; esac
  touches_sensitive_path "$p" && return 2
  touches_sensitive_path "$p/" && return 2
  [ -f "$p" ] || { under_sensitive "$p" && return 2; }
  [ -d "$p" ] && return 1
  [ -e "$p" ] || case "${p##*/}" in *[!A-Za-z0-9_-]*) ;; *) return 1 ;; esac
  return 0
}
~~~
   The line `grep -v '^$' "$W/raw" | sort -u > "$W/all" || true` directly below stays, with the loop that calls `judge_entry`.

10. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.207 to 0.31.208; the new version is HEAD's plus one when this unit runs). Read the new version with `node -p "require('./package.json').version"`.

11. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Lane routing: directory-prefix entries are judged by what could sit beneath them (st-u4 fix 3, VERSION).** `bin/unit-size.sh` still routed a directory that does not exist yet, under a sensitive pattern with an open tail (`adapters/windsurf`, `templates/persona-protocol-v2`, `.claude/settings.d`), as small: the `SENSITIVE_PATHS` regexes were written for files, the entry was tried only as written and with a trailing slash, and `us_listed` treats an entry as a directory prefix. Every entry that is not an existing regular file is now judged by what could sit beneath it: `under_sensitive` reads the literal head of each pattern (the text before its first regex metacharacter) and the entry is sensitive when it is an ancestor of that head or when the head is a prefix of the entry and the pattern's tail is open; a pattern the head reader cannot parse makes every such entry sensitive. A not-yet-existing plain name with no dot (`src/newmodule`) is a new directory and is full (unmeasurable), and an option-like entry read from a contract is unmeasurable as it already was in script mode. tests/unit-size.test.sh gains a witness path for every `SENSITIVE_PATHS` entry and asserts that every proper ancestor of each witness, bare and with a slash, is full in script and contract mode; no contract under docs/plans changes lane or reason against 0.31.207.
~~~
   Replace `VERSION` with the version that edit 10 wrote.

12. command: `node bin/cli.js --update`
   expect: 0

13. command: `bash tests/unit-size.test.sh`
   expect: 0

14. command: `git add bin/unit-size.sh tests/unit-size.test.sh CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "fix(st-u4): directory-prefix lane entries are judged by what could sit beneath them (st-u4)"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it. Stage by path only, never `git add -A`.


## Do NOT touch
- `hooks/hooks.json`, `hooks/` and `.claude/hooks/`
- `hooks/scripts/lib/sensitive-paths.sh` and `hooks/scripts/lib/unit-scope.sh` (st-u1's library is read, never changed)
- `bin/cli.js`, `tests/bin-helpers-scaffold.test.sh` and `tests/validate.sh`
- `agents/` and `templates/` (the orchestrator prose "anything it cannot measure prints `full`" is true again)
- `adapters/`
- `docs/plans/antislop-structural/contracts/st-u4.md`, `docs/plans/antislop-structural/contracts/st-u4-fix1.md` and `docs/plans/antislop-structural/contracts/st-u4-fix2.md` (earlier contracts are not edited)
- `.claude/agents/` and `.claude/bin/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/unit-size.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 9 (the fix 2 judge stays); 23 rows print FAIL and stdout is `1`. Delete the line `  [ -f "$p" ] || { under_sensitive "$p" && return 2; }` instead: 11 rows FAIL. Delete the line `    if [ "$SP_OPEN" = 1 ]; then case "$e" in "$SP_HEAD"*) return 0 ;; esac; fi`: 8 rows FAIL. Delete `    case "$SP_HEAD" in "$e"*) return 0 ;; esac`, `  [ "$re" = '$' ] && SP_OPEN=0` or the `  [ -e "$p" ] || case` line: 2 rows FAIL each. Delete `  [ -d "$p" ] && return 1`: stdout `1`.
   proof: each deletion applied alone with a python replace to a scratch copy of the finished change; stdout `1` each time with the FAIL counts above; the 23 comes from the finished test file run against the 5cb583c1 script.

2. run: `bash -c 'bash tests/unit-size.test.sh | /usr/bin/grep -c "^OK   (o) "'`
   exit: 0
   stdout: `108`
   mutation: delete the line `    mx_full "(o) witness $i ancestor" "$a/"` from tests/unit-size.test.sh; stdout is `68`. Delete the line `    mx_full "(o) witness $i ancestor" "$a"` instead; stdout is `75`.
   proof: python replace in a scratch copy of the finished test file run against the finished script; stdout `68` and `75`, with exit 0 from the test (so only this count notices).

3. run: `cmp bin/unit-size.sh .claude/bin/unit-size.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 12; `--update` leaves the old installed script and cmp prints `differ` and exits 1.
   proof: scratch clone with `.claude/bin/unit-size.sh` restored from 5cb583c1; cmp exit 1.

4. run: `bash -c 'bash tests/bin-helpers-scaffold.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the `'unit-size.sh'` entry from BIN_HELPER_FILES in bin/cli.js; case (a) fails and stdout is `1`.
   proof: as fix 2 criterion 4; this change does not touch bin/cli.js.

5. run: `bash -c 'd=$(mktemp -d); for a in adapters/windsurf templates/persona-protocol-v2 .claude/settings.d src/newmodule src/new.js bin/cli.jsx; do CLAUDE_PROJECT_DIR=$d bash .claude/bin/unit-size.sh zz -- $a src/a.js; done | paste -sd"|"'`
   exit: 0
   stdout: `lane: full files=2 reason=sensitive|lane: full files=2 reason=sensitive|lane: full files=1 reason=sensitive|lane: full files=2 reason=unmeasurable|lane: small files=2 reason=paths|lane: small files=2 reason=paths`
   mutation: copy the 5cb583c1 script over `.claude/bin/unit-size.sh`; all six fields read `lane: small ...`.
   proof: scratch clone with the old script copied to `.claude/bin/`; six `lane: small` fields.

6. run: `bash -c 'd=$(mktemp -d); for a in adapters/windsurf templates/persona-protocol-v2 .claude/settings.d src/newmodule -hooks/x.sh; do printf "## Affected files\n- \140%s\140\n- \140src/a.js\140\n" "$a" > $d/c.md; CLAUDE_PROJECT_DIR=$d bash .claude/bin/unit-size.sh zz --contract $d/c.md; done | paste -sd"|"'`
   exit: 0
   stdout: `lane: full files=2 reason=sensitive|lane: full files=2 reason=sensitive|lane: full files=1 reason=sensitive|lane: full files=2 reason=unmeasurable|lane: full files=2 reason=unmeasurable`
   mutation: copy the 5cb583c1 script over `.claude/bin/unit-size.sh`; every field becomes `lane: small ... reason=contract`.
   proof: scratch clone with the old script copied to `.claude/bin/`; five `lane: small` fields.

7. run: `bash -c 'd=$(mktemp -d); mkdir -p $d/old/bin; git show 5cb583c1:bin/unit-size.sh > $d/old/bin/unit-size.sh; ln -s "$PWD/hooks" $d/old/hooks; n=0; for f in docs/plans/*/contracts/*.md; do a=$(CLAUDE_PROJECT_DIR=$d bash $d/old/bin/unit-size.sh zz --contract $f); b=$(CLAUDE_PROJECT_DIR=$d bash bin/unit-size.sh zz --contract $f); [ "$a" = "$b" ] || n=$((n+1)); done; echo $n'`
   exit: 0
   stdout: `0`
   mutation: delete the line `  touches_sensitive_path "$p" && return 2` from bin/unit-size.sh; the sensitive contracts print medium or small and stdout is `10`.
   proof: python replace in a scratch clone; stdout `10`. The unmutated run prints `0`: no line (lane, files or reason) differs from the 0.31.207 script. Deleting the `under_sensitive` line leaves `0`, since no real contract names a not-yet-existing sensitive directory; criteria 1, 5 and 6 carry that rule.

8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/unit-size.test.sh; the validate.sh block fails and stdout is `1`.
   proof: `grep -c 'bash tests/unit-size.test.sh' tests/validate.sh` prints `1` (line 805); the full run of the finished change exited 0 (about four minutes).

9. run: `bash -c 'git log --format="%H %s" 5cb583c1..HEAD | /usr/bin/grep -cE "^[0-9a-f]+ [a-z]+\(st-u4\): "'`
   exit: 0
   stdout: `1`
   mutation: land the change as two commits with the subject scope `(st-u4)`; stdout is `2`.
   proof: scratch clone, a second commit with the scope `(st-u4)` added; stdout `2`.

10. run: `bash -c 'for c in $(git log --format="%H %s" 5cb583c1..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(st-u4\): " | cut -d" " -f1); do git diff --name-only "$c~1..$c"; done | /usr/bin/grep -vE "^\.claude/" | /usr/bin/grep -vcE "^(bin/unit-size\.sh|tests/unit-size\.test\.sh|CHANGELOG\.md|package\.json|\.claude-plugin/plugin\.json)$"'`
    exit: 1
    stdout: `0`
    mutation: in the fix commit also append a line to agents/orchestrator.md; stdout is `1` and the exit is 0.
    proof: scratch clone, a `(st-u4)` commit with a line appended to agents/orchestrator.md; exit 0, stdout `1`.

11. run: `bash -c 'for c in $(git log --format="%H %s" 5cb583c1..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(st-u4\): " | cut -d" " -f1); do git diff --name-only "$c~1..$c"; done | /usr/bin/grep -E "^\.claude/" | /usr/bin/grep -vcE "^\.claude/(agents/|bin/unit-size\.sh$|persona|protocol-digest\.md$)"'`
    exit: 1
    stdout: `0`
    mutation: in the fix commit also add a file under `.claude/hooks/`; stdout is `1` and the exit is 0.
    proof: scratch clone, a `(st-u4)` commit adding `.claude/hooks/zz.sh`; exit 0, stdout `1`.

12. run: `bash -c 'e=$(git log --format="%H %s" 5cb583c1..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(st-u4\): " | cut -d" " -f1 | head -1); git log --format=%s "$e"..HEAD -- bin/unit-size.sh tests/unit-size.test.sh | /usr/bin/grep -vcE "^[a-z]+\(st-u4\): "'`
    exit: 1
    stdout: `0`
    mutation: make a later commit with another subject that touches tests/unit-size.test.sh; stdout is `1` and the exit is 0.
    proof: scratch clone, the fix commit then an untagged commit appending to tests/unit-size.test.sh; exit 0, stdout `1`.

13. run: `bash -c 'c=$(git log --format="%H %s" 5cb583c1..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(st-u4\): " | cut -d" " -f1 | head -1); for f in package.json .claude-plugin/plugin.json; do p=$(git show "$c~1:$f" | /usr/bin/grep -m1 "\"version\"" | /usr/bin/grep -oE "[0-9]+\.[0-9]+\.[0-9]+"); n=$(git show "$c:$f" | /usr/bin/grep -m1 "\"version\"" | /usr/bin/grep -oE "[0-9]+\.[0-9]+\.[0-9]+"); [ "${p%.*}.$(( ${p##*.} + 1 ))" = "$n" ] && echo "$f ok"; done | paste -sd"|"'`
    exit: 0
    stdout: `package.json ok|.claude-plugin/plugin.json ok`
    mutation: bump `.claude-plugin/plugin.json` only; stdout is `.claude-plugin/plugin.json ok`.
    proof: scratch clone with package.json restored to the parent version in the fix commit; stdout `.claude-plugin/plugin.json ok`.

14. run: `node -e "const v=require('./package.json').version,w=require('./.claude-plugin/plugin.json').version,t=require('fs').readFileSync('CHANGELOG.md','utf8');process.exit(v===w&&t.includes('(st-u4 fix 3, '+v+')')?0:1)" && echo version-sync: ok`
    exit: 0
    stdout: `version-sync: ok`
    mutation: bump `.claude-plugin/plugin.json` only, or leave `VERSION` in the CHANGELOG line; the exit is 1 with empty stdout.
    proof: the same scratch clone as criterion 13; exit 1, empty stdout.

15. run: `bash -c 'tr "\n" " " < CHANGELOG.md | tr -s " " | /usr/bin/grep -cF "is now judged by what could sit beneath it"'`
    exit: 0
    stdout: `1`
    mutation: skip edit 11; stdout is `0` and the exit is 1.
    proof: scratch clone with the phrase reworded in CHANGELOG.md; stdout `0`, exit 1.

16. run: `bash -c 'for f in agents/orchestrator.md .claude/agents/orchestrator.md; do tr "\n" " " < $f | tr -s " " | /usr/bin/grep -cF "anything it cannot measure prints"; done | paste -sd,'`
    exit: 0
    stdout: `1,1`
    mutation: reword `anything it cannot measure prints` in agents/orchestrator.md and in `.claude/agents/orchestrator.md`; stdout is `0,0`.
    proof: scratch clone with both files reworded by sed; stdout `0,0`.

## Pre-resolved context
tdd: yes tests/unit-size.test.sh; edits 1 to 7 add the failing rows and edit 8 runs them red (23 FAIL lines).
blast-radius: bin/unit-size.sh:45-57 (the `judge_entry` comment and function, edit 9; two new functions go in front of it), bin/unit-size.sh:59-64 (the loop that calls it, unchanged), tests/unit-size.test.sh:24-27, :65, :102 and :114 (the lines edits 1 to 7 touch), hooks/scripts/lib/sensitive-paths.sh:11-24 (`SENSITIVE_PATHS`, read through the sourced array) and hooks/scripts/lib/unit-scope.sh (`us_safe_path`, `us_listed`; unchanged). Callers: bin/review-precheck.sh copies `.claude/bookkeeping/<unit>.scope` (the filtered entries, unchanged by this fix), bin/cli.js:656 BIN_HELPER_FILES installs the script, tests/validate.sh:804-808 runs the test. Line numbers are at 5cb583c1.
order: no dependency on the queued units rp-u15, rp-u10, rp-u12, rp-u7, rp-u4, rp-u5, rp-u6, rp-u13, rp-u14 or rp-s1: none lists `bin/unit-size.sh` or `tests/unit-size.test.sh` in its Affected files (checked by grep of their contracts); rp-u6 edits `tests/validate.sh` next to the unit-size echo line (a different file) and rp-s1 writes glossary text about the unit-size script but changes no file this fix edits. This fix does not edit `agents/orchestrator.md`, `docs/harness-glossary.md` or the library. It shares only the three stamp files (`CHANGELOG.md`, `package.json`, `.claude-plugin/plugin.json`) with every queued unit: each inserts after `## [Unreleased]` and sets HEAD plus one, so run it serial with the others in any order and derive the version at dispatch; do not copy 0.31.208.
head-rule: a pattern's head is the text between its leading `^` and its first regex metacharacter (a backslash-escaped character is literal; a character followed by `*`, `+`, `?` or `{` is left out); its tail is closed only when exactly `$` remains, else open. The 11 patterns: `hooks/` open; `.claude/hooks/` open; `adapters/` open; `bin/cli.js` closed; `tests/validate.sh` closed; `templates/persona-protocol` open; `templates/settings-fragment.json` closed; `.claude/settings` open; `.claude-plugin/` open; `agents/` open; `.claude/agents/` open. Entry E is sensitive when E or E/ matches a pattern, or when E is not an existing regular file and, for some pattern, the head starts with E/ (E is an ancestor of the head) or E/ starts with the head and the tail is open. Complete because `us_listed` lists P when P equals E or lies beneath E/: P equal to E is the first test; otherwise P = E/ plus more matches a pattern only if E/ is a prefix of the head, or the head is a prefix of E/ and the tail lets more text follow, and a closed tail does not. An existing regular file gets the first test alone, so `adapters/codex/README.md` stays small while a not-yet-existing one is full; no contract under docs/plans changes lane (criterion 7). The free zones return clean first.
lane-rules: order unchanged outside `judge_entry`: no input, a leading-dash or newline `--` argument (files=0 unmeasurable), then `judge_entry` over every raw entry (unsafe path, glob, trailing slash or leading dash: unmeasurable; free zones: clean; the class on E or E/, or `under_sensitive` for a non-file: sensitive; an existing directory: unmeasurable; a not-yet-existing name of only letters, digits, `_` and `-`: unmeasurable), unmeasurable wins over sensitive, then empty, FAIL record, size and count as before. A not-yet-existing name holding another character (`$ref_total"` from a malformed backtick in the historical contract abt-u04-fix1) keeps the old rule, which keeps every old contract on its lane.
consequence: no lane or reason changes over the contracts under docs/plans against the 5cb583c1 script (criterion 7). Test rows using bare names `a b c d ...` now use `a.js b.js ...`, the (h) row uses `.claude/bin/x`, and the (n) bare `.claude` row prints `sensitive`.
not-in-this-fix: reviewer note (b) (the `-d` check runs against the git top level of the current directory, not `CLAUDE_PROJECT_DIR`) and note (d) (a symlink entry routes small; precheck catches it), and the two fix 2 library notes (`us_entries` drops a bare token with no `/` and no `.`; the regexes are case-sensitive). Contract mode keeps asserting only forms holding a `/` or a `.`.
commit-message: fix(st-u4): directory-prefix lane entries are judged by what could sit beneath them (st-u4)
fix-of: 2026-10-22T16:10:33Z
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
~~~

## Escalation
If any instruction cannot be followed exactly as written (a `before:` payload not found verbatim once, a `--update` refusal, a gate block), STOP and report a spec gap; do not improvise.
