Unit: st-u4

## Objective
Fix round 1 for st-u4 (fix-of: 2026-10-22T14:47:19Z, the latest FAIL block). `bin/unit-size.sh` judges every raw
entry (`us_safe_path`, glob, trailing slash) before it drops `.claude/` and `docs/plans/` entries, so
`docs/plans/../../hooks/x.sh src/a.js`, `.claude/../hooks/x.sh src/a.js` and `docs/plans/x/../../../hooks/x.sh
src/a.js` print `lane: full` (script and contract mode) instead of `lane: small`. A raw `.claude/` entry the
sensitive library flags (`.claude/hooks/x.sh`, a `.claude` settings file) prints `lane: full ... reason=sensitive`;
`.claude/agents/` copies, `.claude/bin/` copies and `docs/plans/` entries stay free. A `--` argument that starts with
a dash or holds a newline prints `lane: full files=0 reason=unmeasurable`. `agents/orchestrator.md` "Lane routing" says
to run the script again when the scope grows after planning, and "Unit scope" asks for the explorer's blast radius
outside the small lane only. Version 0.31.205 to 0.31.206 (HEAD plus one); mirrors refreshed.

## Retrieval
Fast path, no tracker issue. This file is the fix contract of record for the same `Unit: st-u4`; the original contract
is `docs/plans/antislop-structural/contracts/st-u4.md` (commit 7231a42e, version 0.31.205) and stays unchanged. Spec:
`docs/plans/antislop-structural/spec.md`, "Step 4 (st-u4)".

## Affected files
- `tests/unit-size.test.sh` (anchor: line matching `is "(f) a leading slash" 'lane: full files=1 reason=unmeasurable' u1 -- /hooks/x.sh`)
- `bin/unit-size.sh` (anchors: line matching `[ "$n" -gt 0 ] || emit full 0 empty`; line matching `shift; printf '%s\n' "$@" > "$W/raw"; src=paths`)
- `agents/orchestrator.md` (anchors: line matching `You may move a unit to a heavier lane than it prints, never to a lighter one.`; line matching `or test directory, and the explorer's blast radius, and never leave it empty.`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.205",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- generated only, by `node bin/cli.js --update`: `.claude/bin/unit-size.sh`, `.claude/agents/*.md`, `.claude/persona-protocol.md`, `.claude/persona-protocol-slim.md`, `.claude/protocol-digest.md`, the config's `fileHashes` and `pluginVersion`

## Ordered edits

1. file: `tests/unit-size.test.sh`
   anchor: line matching `is "(f) a leading slash" 'lane: full files=1 reason=unmeasurable' u1 -- /hooks/x.sh`
   indent: 0
   insert-after:
~~~
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
~~~
   The new rows (f), (l) and (m) sit directly after the existing (f) rows; nothing else in the file changes.

2. command: `bash tests/unit-size.test.sh`
   expect: 1
   The red step: the script still drops bookkeeping entries before judging them, so eleven of the new rows print FAIL.

3. file: `bin/unit-size.sh`
   anchor: line matching `[ "$n" -gt 0 ] || emit full 0 empty`
   indent: 0
   before:
~~~
[ "$n" -gt 0 ] || emit full 0 empty
~~~
   after:
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
[ "$n" -gt 0 ] || emit full 0 empty
~~~

4. file: `bin/unit-size.sh`
   anchor: line matching `shift; printf '%s\n' "$@" > "$W/raw"; src=paths`
   indent: 0
   before:
~~~
shift; printf '%s\n' "$@" > "$W/raw"; src=paths
~~~
   after:
~~~
shift
  # An argument that is an option or holds a newline cannot be one path: unmeasurable.
  for a in "$@"; do
    case "$a" in -*|*$'\n'*) emit full 0 unmeasurable ;; esac
  done
  printf '%s\n' "$@" > "$W/raw"; src=paths
~~~

5. file: `agents/orchestrator.md`
   anchor: line matching `You may move a unit to a heavier lane than it prints, never to a lighter one.`
   indent: 0
   before:
~~~
output is `full` too. You may move a unit to a heavier lane than it prints, never to a lighter one.
~~~
   after:
~~~
output is `full` too. You may move a unit to a heavier lane than it prints, never to a lighter one.
When the scope grows after planning (a lead-programmer proposes a file outside `## Affected files`), run
`unit-size.sh` again with the grown list and take the heavier lane; the reviewer tier still comes from
`reviewer-tier.sh` over the real diff.
~~~

6. file: `agents/orchestrator.md`
   anchor: line matching `or test directory, and the explorer's blast radius, and never leave it empty.`
   indent: 0
   before:
~~~
or test directory, and the explorer's blast radius, and never leave it empty. A file the user names in the
~~~
   after:
~~~
or test directory, and, outside the small lane (see "Lane routing"), the explorer's blast radius, and
never leave it empty. A file the user names in the
~~~

7. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.205 to 0.31.206; the new version is HEAD's plus one when this unit runs).

8. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Lane routing: raw entries judged first (st-u4 fix 1, VERSION).** `bin/unit-size.sh` judged `.claude/` and `docs/plans/` entries only after dropping them, so `docs/plans/../../hooks/x.sh` or `.claude/../hooks/x.sh` beside `src/a.js` printed small instead of full; every raw entry now goes through `us_safe_path` and the glob and trailing-slash check first, a hand-edited `.claude/hooks/` or `.claude/settings*.json` entry is full (sensitive), `.claude/agents/` copies and other generated `.claude/` and `docs/plans/` entries stay free, and a `--` argument that starts with a dash or holds a newline is full (unmeasurable). agents/orchestrator.md "Lane routing" says to run the script again when the scope grows after planning, and "Unit scope" asks for the explorer's blast radius outside the small lane only. tests/unit-size.test.sh gains the `..`, glob, sensitive `.claude/`, free-copy and dash rows.
~~~
   Replace `VERSION` with the version that edit 7 wrote.

9. command: `node bin/cli.js --update`
   expect: 0

10. command: `bash tests/unit-size.test.sh`
    expect: 0

11. command: `git add bin/unit-size.sh tests/unit-size.test.sh agents/orchestrator.md CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "fix(st-u4): judge raw entries before the bookkeeping filter, sensitive .claude hooks and settings entries and option-like arguments are full"`
    expect: 0
    Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it. Stage by path only, never `git add -A`.

## Do NOT touch
- `hooks/hooks.json`, `hooks/` and `.claude/hooks/` (reviewer-tier.sh among them: it still measures the actual diff; criterion 12)
- `hooks/scripts/lib/sensitive-paths.sh` and `hooks/scripts/lib/unit-scope.sh` (st-u1's library; this fix only sources it, so the `.claude/agents/` exemption lives in the script)
- `bin/cli.js`, `tests/bin-helpers-scaffold.test.sh` and `tests/validate.sh` (the helper list, the scaffold list and the validate.sh block stay as st-u4 left them; criterion 12)
- `adapters/` and `templates/` (the codex and cursor ports keep today's pipeline; criterion 12)
- `agents/lead-programmer.md`, `agents/reviewer.md` and `agents/spec-master.md` (criterion 12)
- `docs/plans/antislop-structural/contracts/st-u4.md` (the original contract is not edited)
- `.claude/agents/` and `.claude/bin/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/unit-size.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 3; the (f) `..` and (l) sensitive rows print FAIL and stdout is `1`. Skip edit 4 instead: the (m) rows print FAIL and stdout is `1`.
   proof: skip edit 3 and skip edit 4 each applied alone to a scratch worktree of the finished change; stdout `1` both times.

2. run: `cmp bin/unit-size.sh .claude/bin/unit-size.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 9; `--update` leaves the old installed script and cmp prints `differ` and exits 1.
   proof: scratch worktree of the finished change with `.claude/bin/unit-size.sh` restored from HEAD; cmp exit 1.

3. run: `bash -c 'bash tests/bin-helpers-scaffold.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the `'unit-size.sh'` entry from BIN_HELPER_FILES in bin/cli.js; case (a) fails and stdout is `1`.
   proof: scratch worktree of the finished change with the entry deleted; stdout `1`.

4. run: `bash -c 'bash .claude/bin/unit-size.sh st-u4 --contract docs/plans/antislop-structural/contracts/st-u4.md | grep -cE "^lane: full files=[0-9]+ reason=sensitive$"'`
   exit: 0
   stdout: `1`
   mutation: delete the `while` loop that ends `done < "$W/entries"` after the line `touches_sensitive_path "$p" && emit full "$n" sensitive` in bin/unit-size.sh and rerun `node bin/cli.js --update`; the st-u4 contract prints `lane: medium files=<n> reason=contract`, stdout `0` and exit 1.
   proof: scratch worktree of the finished change with that loop deleted and the script copied to `.claude/bin/`; stdout `0`, exit 1.

5. run: `bash -c 'd=$(mktemp -d); for a in docs/plans/../../hooks/x.sh .claude/../hooks/x.sh docs/plans/x/../../../hooks/x.sh; do CLAUDE_PROJECT_DIR=$d bash .claude/bin/unit-size.sh zz -- $a src/a.js; done | grep -cx "lane: full files=1 reason=unmeasurable"; rm -rf "$d"'`
   exit: 0
   stdout: `3`
   mutation: skip edit 3; the three invocations print `lane: small files=1 reason=paths` and stdout is `0`.
   proof: skip edit 3 in a scratch worktree of the finished change; stdout `0`.

6. run: `bash -c 'd=$(mktemp -d); printf "## Affected files\n- \140docs/plans/../../hooks/stop-gate.sh\140\n- \140src/a.js\140\n" > $d/c.md; CLAUDE_PROJECT_DIR=$d bash .claude/bin/unit-size.sh zz --contract $d/c.md; rm -rf "$d"'`
   exit: 0
   stdout: `lane: full files=1 reason=unmeasurable`
   mutation: skip edit 3; it prints `lane: small files=1 reason=contract`.
   proof: skip edit 3 in a scratch worktree of the finished change; prints `lane: small files=1 reason=contract`.

7. run: `bash -c 'd=$(mktemp -d); CLAUDE_PROJECT_DIR=$d bash .claude/bin/unit-size.sh zz -- .claude/hooks/x.sh src/a.js; rm -rf "$d"'`
   exit: 0
   stdout: `lane: full files=1 reason=sensitive`
   mutation: skip edit 3; it prints `lane: small files=1 reason=paths`.
   proof: skip edit 3 in a scratch worktree of the finished change; prints `lane: small files=1 reason=paths`.

8. run: `bash -c 'd=$(mktemp -d); export CLAUDE_PROJECT_DIR=$d; u=.claude/bin/unit-size.sh; { bash $u zz -- .claude/agents/x.md src/a.js; bash $u zz -- .claude/bin/x.sh docs/plans/p/s.md src/a.js test/a.test.js; bash $u zz -- a b c d e .claude/agents/y.md; } | paste -sd"|"; rm -rf "$d"'`
   exit: 0
   stdout: `lane: small files=1 reason=paths|lane: small files=2 reason=paths|lane: medium files=5 reason=paths`
   mutation: delete the line `    .claude/agents/*) ;;` from bin/unit-size.sh and copy it over `.claude/bin/unit-size.sh`; the first field becomes `lane: full files=1 reason=sensitive` and the third `lane: full files=5 reason=sensitive`.
   proof: the same deletion in a scratch worktree of the finished change; stdout `lane: full files=1 reason=sensitive|lane: small files=2 reason=paths|lane: full files=5 reason=sensitive`.

9. run: `bash -c 'd=$(mktemp -d); export CLAUDE_PROJECT_DIR=$d; u=.claude/bin/unit-size.sh; { bash $u zz -- -rf; bash $u zz -- src/a.js -rf; bash $u zz -- "$(printf "src/a.js\nsrc/b.js")"; } | grep -cx "lane: full files=0 reason=unmeasurable"; rm -rf "$d"'`
   exit: 0
   stdout: `3`
   mutation: skip edit 4; the three invocations print `lane: small` and stdout is `0`.
   proof: skip edit 4 in a scratch worktree of the finished change; stdout `0`.

10. run: `bash -c 'for f in agents/orchestrator.md .claude/agents/orchestrator.md; do for p in "When the scope grows after planning" "outside the small lane (see \"Lane routing\"), the explorer"; do tr "\n" " " < $f | tr -s " " | /usr/bin/grep -cF -- "$p"; done; done | paste -sd,'`
   exit: 0
   stdout: `1,1,1,1`
   mutation: skip edit 5; stdout is `0,1,0,1`. Skip edit 6 instead: stdout is `1,0,1,0`. Skip edit 9 instead: the mirror keeps the old text and stdout is `1,1,0,0`.
   proof: each skip applied alone to a scratch worktree of the finished change.

11. run: `bash -c 'node tests/adapter-protocol-parity.test.js >/dev/null && node tests/protocol-cross-references.test.js >/dev/null && bash tests/persona-prose-pins.test.sh >/dev/null && node tests/writer-tier-consistency.test.js >/dev/null && node tests/cli-backfill.test.js >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: in agents/orchestrator.md reword `Each implementer tier gets two attempts` to `Each implementer tier gets one attempt`; writer-tier-consistency fails and stdout is `1`.
   proof: scratch worktree of the finished change with that rewording; stdout `1`.

12. run: `bash -c 'l=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(st-u4\): " | cut -d" " -f1 | head -1); git diff --name-only "$l~1..$l" -- adapters hooks templates bin/cli.js tests/validate.sh tests/bin-helpers-scaffold.test.sh agents/lead-programmer.md agents/reviewer.md agents/spec-master.md | wc -l'`
   exit: 0
   stdout: `0`
   mutation: in the fix commit also append a line to bin/cli.js; stdout is `1`.
   proof: scratch worktree, fix commit with a bin/cli.js line appended; stdout `1`.

13. run: `bash -c 'l=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(st-u4\): " | cut -d" " -f1 | head -1); bash hooks/scripts/version-stamp-check.sh "$l~1..$l" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 7; stdout reads `version-stamp-check: violation touched: yes`.
   proof: scratch worktree of the finished change committed without the bump; stdout `version-stamp-check: violation touched: yes`.

14. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;process.exit(a===b?0:1)" && echo version-sync: ok`
   exit: 0
   stdout: `version-sync: ok`
   mutation: run edit 7 on `.claude-plugin/plugin.json` only; the versions differ and the exit is 1 with empty stdout.
   proof: scratch worktree, package.json restored to HEAD; exit 1, empty stdout.

15. run: `bash -c 'l=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(st-u4\): " | cut -d" " -f1 | head -1); git log --format=%s "$l"..HEAD -- bin/unit-size.sh tests/unit-size.test.sh agents/orchestrator.md | grep -vcE "^[a-z]+\(st-u4\): "'`
   exit: 1
   stdout: `0`
   mutation: make a later commit with another subject that touches agents/orchestrator.md; stdout is `1` and the exit is 0.
   proof: scratch worktree, fix commit then an untagged commit appending to agents/orchestrator.md; exit 0, stdout `1`.

16. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/unit-size.test.sh; the validate.sh block fails and stdout is `1`.
   proof: scratch worktree: `grep -c 'bash tests/unit-size.test.sh' tests/validate.sh` prints `1`, and criterion 1 with the same mutation prints `1`; the full validate.sh run of the finished change exited 0.

## Pre-resolved context
tdd: yes tests/unit-size.test.sh; edit 1 adds the failing rows and edit 2 runs them red.
blast-radius: bin/unit-size.sh:32 (the `--` branch, edit 4), bin/unit-size.sh:36-39 (bookkeeping filter and empty check, edit 3), bin/unit-size.sh:40-48 (the loops on the filtered entries, unchanged), tests/unit-size.test.sh:37 (the last (f) row), agents/orchestrator.md:87 (Lane routing), agents/orchestrator.md:142 (Unit scope). Callers: bin/review-precheck.sh:113 copies `.claude/bookkeeping/<unit>.scope` (the filtered entries, unchanged by this fix), bin/cli.js BIN_HELPER_FILES installs the script. Line numbers are at 7231a42e.
order: this fix has no dependency on the queued units rp-u15, rp-u10, rp-u12, rp-u7, rp-u4, rp-u6, rp-u13, rp-u14 or rp-s1: none edits bin/unit-size.sh, tests/unit-size.test.sh or the two orchestrator paragraphs (checked by grep of their contracts). It edits agents/orchestrator.md and the version files like rp-u5, so run it before rp-u5 or after it (never beside it), and serial with every unit that bumps the version (each sets HEAD plus one; derive the version at dispatch, do not copy 0.31.206). rp-u5's pin rows in tests/prompt-diet-pins.test.sh read the line `Skip the scribe dispatch entirely...`, which this fix does not touch.
lane-rules: the check order is now: no input, a leading-dash or newline `--` argument (files=0 unmeasurable), then over the raw entries an `us_safe_path` or glob or trailing-slash reject (unmeasurable), then a sensitive `.claude/` entry other than `.claude/agents/` (sensitive), then empty, then the existing checks on the filtered entries. The scope file still holds the filtered entries.
consequence: a contract that lists a generated glob such as `.claude/agents/*.md` now prints `reason=unmeasurable` where it printed `reason=sensitive`; measured over the 134 contracts under docs/plans, 27 change reason and none changes lane.
not-in-this-fix: the reviewer's note 5 (the Affected-files extraction counts the anchor-text token `FILES="ladder-tier.sh` as an entry, count only) is a follow-up.
commit-message: fix(st-u4): judge raw entries before the bookkeeping filter, sensitive .claude hooks and settings entries and option-like arguments are full
fix-of: 2026-10-22T14:47:19Z
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
