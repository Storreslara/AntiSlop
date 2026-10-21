Unit: aof-u3b

## Objective
Fix forward on aof-u3 (1d4abf5a, reviewer PASS with a design finding). The unit-scope rule as landed forbids
edits the repo itself requires, and its reviewer half rests on a judgement call. After this unit:
- `agents/lead-programmer.md` and `agents/reviewer.md`, and their codex and cursor ports, name the same
  standing exceptions to `## Affected files`: the version-stamp files (in this repo `.claude-plugin/plugin.json`,
  `package.json`, `CHANGELOG.md`; constitution P3, and validate.sh's version-sync check for `package.json`); a
  path that an acceptance-criteria command names literally; and, in a fix round, a path named in a defect of
  the unit's `.fail` record or listed under its fix contract's `## Affected files`. Generated mirrors and
  `fileHashes` live under `.claude/`, which both rules already exempt.
- The reviewer's clause "unless an acceptance criterion of the unit requires that file" is replaced by those
  explicit couplings.
- The codex and cursor orchestrator ports state the sending half of the rule (every lead-programmer dispatch
  carries `## Affected files`), because their reviewer ports already FAIL against that list.
- `tests/unit-scope-prose.test.sh` pins all of it in the 6 persona files, their 2 `.claude/` mirrors and the 2 orchestrator ports.

No gate, hook, template or `bin/` file changes. It runs after aof-u3 and before aof-u4.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-overhead-fixes/spec.md`, "Step 3 (aof-u3)", and the
dispatch order in `docs/plans/antislop-quick-wins/spec.md`. This file is the contract of record.

## Affected files
- `tests/unit-scope-prose.test.sh` (anchor: line matching `exit "$fail"`)
- `agents/lead-programmer.md`, `adapters/codex/agents/lead-programmer.toml`, `adapters/cursor/agents/lead-programmer.md` (anchor: line matching `- **Unit scope**: edit only the files listed`)
- `agents/reviewer.md`, `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md` (anchor: line matching `A changed file outside the unit's scope is also a FAIL reason: list`)
- `adapters/codex/agents/orchestrator.toml` (anchor: line matching `produce vague or over-scoped work.`)
- `adapters/cursor/agents/orchestrator.md` (anchor: line matching `vague or over-scoped work.`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md`, `.claude/persona-protocol*.md`,
  `.claude/protocol-digest.md` (version stamps) and the config's `fileHashes`

## Ordered edits
1. file: `tests/unit-scope-prose.test.sh`
   anchor: line matching `exit "$fail"` (the last line)
   indent: 0
   before: `exit "$fail"`
   after:
~~~
# aof-u3b: standing scope exceptions in both rules, the reviewer's judgement clause gone, and the
# orchestrator ports state the sending half of the rule their reviewer ports already enforce.
hasnot() { # <file> <phrase>
  if [ -f "$1" ] && ! tr -s ' \n' ' ' < "$1" | grep -qF -- "$2"; then echo "ok   $1 (absent) $2"; else echo "FAIL $1 (present or missing) $2"; fail=1; fi
}
for f in agents/lead-programmer.md .claude/agents/lead-programmer.md adapters/codex/agents/lead-programmer.toml adapters/cursor/agents/lead-programmer.md \
         agents/reviewer.md .claude/agents/reviewer.md adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md; do
  has "$f" 'the version-stamp files that the project'"'"'s constitution or merge gate requires every such commit to change'
  has "$f" '(in this plugin'"'"'s own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`)'
  has "$f" 'a path that one of the unit'"'"'s acceptance-criteria commands names literally'
  has "$f" 'a path named in a defect of the unit'"'"'s `.fail` record or listed under its fix contract'"'"'s `## Affected files`'
  hasnot "$f" 'unless an acceptance criterion of the unit requires that file'
done
for f in adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md; do
  has "$f" 'Every lead-programmer dispatch carries `## Affected files`'
  has "$f" 'that no standing exception covers'
done
exit "$fail"
~~~
2. command: `bash tests/unit-scope-prose.test.sh`
   expect: 1
   The red step: the new rows fail before the persona edits.
3. file: `agents/lead-programmer.md`
   anchor: line matching `- **Unit scope**: edit only the files listed`
   indent: 0
   before:
~~~
- **Unit scope**: edit only the files listed under your dispatch's `## Affected files`, plus
  `docs/plans/` and `.claude/` bookkeeping. Any other change you believe is needed (a glossary entry, a
  README line, an ADR, a caller outside the list) goes in your report under
  `Proposed out-of-scope changes:` and is not applied.
~~~
   after:
~~~
- **Unit scope**: edit only the files listed under your dispatch's `## Affected files`, plus
  `docs/plans/` and `.claude/` bookkeeping. Standing exceptions, in scope without being listed: the
  version-stamp files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally; and, in a fix round, a path named in a defect
  of the unit's `.fail` record or listed under its fix contract's `## Affected files`. Any other change you
  believe is needed (a glossary entry, a README line, an ADR, a caller outside the list) goes in your report
  under `Proposed out-of-scope changes:` and is not applied.
~~~
4. file: `adapters/codex/agents/lead-programmer.toml`
   anchor: line matching `- **Unit scope**: edit only the files listed`
   indent: 0
   before:
~~~
- **Unit scope**: edit only the files listed under your dispatch's `## Affected files`, plus
  `docs/plans/` and `.claude/` bookkeeping. Any other change you believe is needed (a glossary entry, a
  README line, an ADR, a caller outside the list) goes in your report under
  `Proposed out-of-scope changes:` and is not applied.
~~~
   after:
~~~
- **Unit scope**: edit only the files listed under your dispatch's `## Affected files`, plus
  `docs/plans/` and `.claude/` bookkeeping. Standing exceptions, in scope without being listed: the
  version-stamp files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally; and, in a fix round, a path named in a defect
  of the unit's `.fail` record or listed under its fix contract's `## Affected files`. Any other change you
  believe is needed (a glossary entry, a README line, an ADR, a caller outside the list) goes in your report
  under `Proposed out-of-scope changes:` and is not applied.
~~~
5. file: `adapters/cursor/agents/lead-programmer.md`
   anchor: line matching `- **Unit scope**: edit only the files listed`
   indent: 0
   before:
~~~
- **Unit scope**: edit only the files listed under your dispatch's `## Affected files`, plus
  `docs/plans/` and `.claude/` bookkeeping. Any other change you believe is needed (a glossary entry, a
  README line, an ADR, a caller outside the list) goes in your report under
  `Proposed out-of-scope changes:` and is not applied.
~~~
   after:
~~~
- **Unit scope**: edit only the files listed under your dispatch's `## Affected files`, plus
  `docs/plans/` and `.claude/` bookkeeping. Standing exceptions, in scope without being listed: the
  version-stamp files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally; and, in a fix round, a path named in a defect
  of the unit's `.fail` record or listed under its fix contract's `## Affected files`. Any other change you
  believe is needed (a glossary entry, a README line, an ADR, a caller outside the list) goes in your report
  under `Proposed out-of-scope changes:` and is not applied.
~~~
6. file: `agents/reviewer.md`
   anchor: line matching `A changed file outside the unit's scope is also a FAIL reason: list`
   indent: 0
   before:
~~~
  A changed file outside the unit's scope is also a FAIL reason: list
  `git diff --name-only <baseline>..HEAD -- . ':(exclude).claude' ':(exclude)docs/plans'` and FAIL on any
  path not listed under the dispatch's `## Affected files`, unless an acceptance criterion of the unit
  requires that file. Style preferences and robustness nice-to-haves
~~~
   after:
~~~
  A changed file outside the unit's scope is also a FAIL reason: list
  `git diff --name-only <baseline>..HEAD -- . ':(exclude).claude' ':(exclude)docs/plans'` and FAIL on any
  path not listed under the dispatch's `## Affected files` and not covered by a standing exception: the
  version-stamp files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally; and, after a FAIL, a path named in a defect of
  the unit's `.fail` record or listed under its fix contract's `## Affected files`. Style preferences and
  robustness nice-to-haves
~~~
7. file: `adapters/codex/agents/reviewer.toml`
   anchor: line matching `A changed file outside the unit's scope is also a FAIL reason: list`
   indent: 0
   before:
~~~
  A changed file outside the unit's scope is also a FAIL reason: list
  `git diff --name-only <baseline>..HEAD -- . ':(exclude).claude' ':(exclude)docs/plans'` and FAIL on any
  path not listed under the dispatch's `## Affected files`, unless an acceptance criterion of the unit
  requires that file. Style preferences and robustness nice-to-haves
~~~
   after:
~~~
  A changed file outside the unit's scope is also a FAIL reason: list
  `git diff --name-only <baseline>..HEAD -- . ':(exclude).claude' ':(exclude)docs/plans'` and FAIL on any
  path not listed under the dispatch's `## Affected files` and not covered by a standing exception: the
  version-stamp files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally; and, after a FAIL, a path named in a defect of
  the unit's `.fail` record or listed under its fix contract's `## Affected files`. Style preferences and
  robustness nice-to-haves
~~~
8. file: `adapters/cursor/agents/reviewer.md`
   anchor: line matching `A changed file outside the unit's scope is also a FAIL reason: list`
   indent: 0
   before:
~~~
  A changed file outside the unit's scope is also a FAIL reason: list
  `git diff --name-only <baseline>..HEAD -- . ':(exclude).claude' ':(exclude)docs/plans'` and FAIL on any
  path not listed under the dispatch's `## Affected files`, unless an acceptance criterion of the unit
  requires that file. Style preferences and robustness nice-to-haves
~~~
   after:
~~~
  A changed file outside the unit's scope is also a FAIL reason: list
  `git diff --name-only <baseline>..HEAD -- . ':(exclude).claude' ':(exclude)docs/plans'` and FAIL on any
  path not listed under the dispatch's `## Affected files` and not covered by a standing exception: the
  version-stamp files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally; and, after a FAIL, a path named in a defect of
  the unit's `.fail` record or listed under its fix contract's `## Affected files`. Style preferences and
  robustness nice-to-haves
~~~
9. file: `adapters/codex/agents/orchestrator.toml`
   anchor: line matching `produce vague or over-scoped work.` (end of the "Delegation contract" paragraph)
   indent: 0
   insert-after:
~~~

Every lead-programmer dispatch carries `## Affected files`. With no dispatch contract, write it yourself
from the paths the request names, their tests and the files they affect, and never leave it empty: the
reviewer FAILs any changed file outside it that no standing exception covers.
~~~
10. file: `adapters/cursor/agents/orchestrator.md`
   anchor: line matching `vague or over-scoped work.` (end of the "Delegation contract" paragraph)
   indent: 0
   insert-after:
~~~

Every lead-programmer dispatch carries `## Affected files`. With no dispatch contract, write it yourself
from the paths the request names, their tests and the files they affect, and never leave it empty: the
reviewer FAILs any changed file outside it that no standing exception covers.
~~~
11. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.185 to 0.31.186).
12. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Unit-scope exceptions (aof-u3b, VERSION).** agents/lead-programmer.md and agents/reviewer.md (and their codex and cursor ports) name the standing exceptions to the unit scope: the version-stamp files (in this repo `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`), a path an acceptance-criteria command names literally, and in a fix round the paths the unit's `.fail` record or fix contract names. The reviewer's "unless an acceptance criterion requires that file" judgement clause is gone. The codex and cursor orchestrator ports now state that every lead-programmer dispatch carries `## Affected files`. tests/unit-scope-prose.test.sh pins all of it.
~~~
   Replace `VERSION` with the version that edit 11 wrote.
13. command: `node bin/cli.js --update`
   expect: 0
14. command: `bash tests/unit-scope-prose.test.sh`
   expect: 0
15. command: `git add -u && git commit -m "fix(aof-u3b): standing unit-scope exceptions; orchestrator ports carry the scope rule"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `agents/orchestrator.md` (its "Unit scope" paragraph already states the sending half; criterion 4 checks it is unchanged)
- `hooks/`, `bin/`, `templates/` (no gate, script or protocol change; criterion 4)
- `.claude/` copies by hand: `node bin/cli.js --update` rewrites them, including the version stamp in
  `.claude/protocol-digest.md` and `.claude/persona-protocol*.md`; that stamp change is expected, not a scope breach
- `docs/plans/antislop-overhead-fixes/contracts/aof-u3.md` (the landed contract stays the record of what aof-u3 did)

## Acceptance criteria
1. run: `bash -c 'bash tests/unit-scope-prose.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 9; the codex orchestrator-port rows fail and stdout is `1` (spec-master ran it on a clone).
2. run: `bash -c 'for f in agents/reviewer.md .claude/agents/reviewer.md adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md; do tr -s " \n" " " < "$f" | grep -qF "unless an acceptance criterion of the unit requires that file" && echo "still in $f"; done; true'`
   exit: 0
   stdout: empty
   mutation: skip edits 6 to 8; it prints four `still in` lines (it prints them on the pre-unit tree).
3. run: `bash -c 'node bin/cli.js --update >/dev/null 2>&1; git status --porcelain -- .claude agents adapters | wc -l'`
   exit: 0
   stdout: `0`
   mutation: append a line to `.claude/agents/reviewer.md` by hand; `--update` leaves the diverged mirror and stdout is `1` (spec-master ran it on a clone).
4. run: `bash -c 'b=$(git log --format=%H --grep="(aof-u3b)" | tail -1); git diff --name-only "$b^..HEAD" -- hooks bin templates agents/orchestrator.md | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `agents/orchestrator.md` in an aof-u3b commit; stdout is at least `1`.
5. run: `bash -c 'node tests/adapter-protocol-parity.test.js >/dev/null && bash tests/persona-prose-pins.test.sh >/dev/null && node tests/protocol-cross-references.test.js >/dev/null && python3 -c "import tomllib; [tomllib.load(open(p, \"rb\")) for p in (\"adapters/codex/agents/lead-programmer.toml\", \"adapters/codex/agents/reviewer.toml\", \"adapters/codex/agents/orchestrator.toml\")]"; echo $?'`
   exit: 0
   stdout: `0`
   mutation: put a stray `"""` inside the codex reviewer port's instructions; tomllib fails and stdout is `1`.
6. run: `bash -c 'b=$(git log --format=%H --grep="(aof-u3b)" | tail -1); bash hooks/scripts/version-stamp-check.sh "$b^..HEAD" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 11; stdout reads `version-stamp-check: violation touched: yes`.
7. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/unit-scope-prose.test.sh; validate.sh exits 1 and stdout is `1` (the test is registered since aof-u3).

## Pre-resolved context
tdd: yes the new rows (edit 1) fail first (edit 2: 17 FAIL lines on the pre-unit tree); spec-master applied edits 1 to 15 to a clone at b3c700b9 and criteria 1 to 6 passed there (validate.sh not run by spec-master).
blast-radius: agents/lead-programmer.md:66 (Unit scope bullet), agents/reviewer.md:28-35 (Materiality filter), adapters/codex/agents/orchestrator.toml:60, adapters/cursor/agents/orchestrator.md:56 (end of Delegation contract), tests/unit-scope-prose.test.sh:19. Line numbers are at b3c700b9.
findings-verified: (1) aof-u1, aof-u2 and aof-u3 each changed `package.json` (validate.sh "package.json / plugin.json version sync" fails otherwise) without listing it, and constitution P3 requires the plugin.json bump and the CHANGELOG entry in the same commit. (2) aof-u1's fix commits 895f5427 (`tests/writer-tier-consistency.test.js`) and 68235153 (`tests/cli-backfill.test.js`) changed files no contract listed, as the FAIL record required. (3) The codex and cursor orchestrator ports omit the explorer-first paragraph that the source's Unit scope paragraph extends, but their reviewer ports FAIL any path outside `## Affected files`, so a port orchestrator that never writes the list would make every port review FAIL; the ports get one condensed paragraph in their own "Delegation contract" section. (4) `.claude/protocol-digest.md` changes on every `--update` (version stamp), so it is listed as generated, not forbidden.
same-text: edits 3 to 5 and 6 to 8 repeat one payload for three files each; spec-master checked that the `before:` payload occurs exactly once in each of the six files. The ports already used the source wording for these bullets (aof-u3), and the new text names no dot-directory, so it stays identical across `.claude`, `.codex` and `.cursor` layouts.
explicit-couplings: the reviewer's former judgement clause becomes three checkable sources: the version-stamp file list, the literal paths in the unit's acceptance-criteria `run:` commands, and, after a FAIL, the paths in the `.fail` record's defects or the fix contract's `## Affected files`.
version: `.claude-plugin/plugin.json` and `package.json` read 0.31.185 after aof-u3; edit 11 adds one (expected 0.31.186). aof-u4 then expects 0.31.187 and the quick-win units 0.31.188 to 0.31.193.
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2); criterion 3 is the mirror-equality check.
commit-message: fix(aof-u3b): standing unit-scope exceptions; orchestrator ports carry the scope rule
diagnosis: none
review-packet:
~~~
unit: aof-u3b
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
~~~

## Escalation
If a `before:` payload is not found verbatim in any of the six files, stop and report the current text; do not
improvise. If `node bin/cli.js --update` reports a diverged mirror, quote it and stop. If a gate blocks a
command, report it and wait. Anything outside "Affected files" goes to your report as a proposal.
