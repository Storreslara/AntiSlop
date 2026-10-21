Unit: rp-u1

## Objective
Finding A (safety). The unit-scope rule in `agents/lead-programmer.md` and `agents/reviewer.md`, and in
their codex and cursor ports, exempts "a path that one of the unit's acceptance-criteria commands names
literally". A criterion such as `bash tests/validate.sh` therefore lets a unit edit, unlisted, the very
script it is graded by. After this unit, in all six copies:
- the criteria exception covers only a file a criterion command reads, never a script or test it runs
  (the program it starts, or the script it hands to `bash`, `sh`, `node` or `python3`, such as
  `tests/validate.sh`), which is in scope only when listed;
- a path under the contract's `## Do NOT touch` is out of scope even when a standing exception covers it;
- "version-stamp files" becomes "bump files" (the repo's existing term; `CONTEXT.md` **Version-stamped
  file** means something else);
- lead-programmer only: an existing test the change breaks goes to `Proposed out-of-scope changes:`, and
  the lead-programmer stops as blocked naming it if the suite cannot pass without it.
The other standing exceptions (bump files, fix-round paths, `.claude/` and `docs/plans/`) are unchanged.
`tests/unit-scope-prose.test.sh` pins it. No gate, hook, template or `bin/` file changes. This is spec Step 1.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 1 (rp-u1)" and
"Context", finding A. This file is the contract of record. Dispatch it after the unit currently in flight
and before st-u1 (`docs/plans/antislop-structural/contracts/st-u1.md`); it shares no anchor with qw-u5,
qw-u6 or st-u1 to st-u4.

## Affected files
- `tests/unit-scope-prose.test.sh` (anchors: line matching `  has "$f" 'the version-stamp files that the project'"'"'s constitution or merge gate requires every such commit to change'`; line matching `for f in adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md; do`)
- `agents/lead-programmer.md`, `adapters/codex/agents/lead-programmer.toml`, `adapters/cursor/agents/lead-programmer.md` (anchor: line matching `- **Unit scope**: edit only the files listed under your dispatch's`)
- `agents/reviewer.md`, `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md` (anchor: line matching `  path not listed under the dispatch's`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md`, `.claude/persona-protocol*.md`,
  `.claude/protocol-digest.md` (version stamps) and the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/unit-scope-prose.test.sh`
   anchor: line matching `  has "$f" 'the version-stamp files that the project'"'"'s constitution or merge gate requires every such commit to change'`
   indent: 2
   before:
~~~
  has "$f" 'the version-stamp files that the project'"'"'s constitution or merge gate requires every such commit to change'
  has "$f" '(in this plugin'"'"'s own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`)'
  has "$f" 'a path that one of the unit'"'"'s acceptance-criteria commands names literally'
~~~
   after:
~~~
  has "$f" 'the bump files that the project'"'"'s constitution or merge gate requires every such commit to change'
  has "$f" '(in this plugin'"'"'s own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`)'
  has "$f" 'a path that one of the unit'"'"'s acceptance-criteria commands names literally as a file it reads, never a script or test it runs'
  has "$f" 'such as `tests/validate.sh`), which is in scope only when listed'
  has "$f" 'under the contract'"'"'s `## Do NOT touch`'
  has "$f" 'even when a standing exception covers it'
  hasnot "$f" 'the version-stamp files that'
  hasnot "$f" 'commands names literally; and'
~~~
2. file: `tests/unit-scope-prose.test.sh`
   anchor: line matching `for f in adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md; do`
   indent: 0
   before: `for f in adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md; do`
   after:
~~~
# rp-u1: an existing test the change breaks is proposed, never edited unlisted.
for f in agents/lead-programmer.md .claude/agents/lead-programmer.md adapters/codex/agents/lead-programmer.toml adapters/cursor/agents/lead-programmer.md; do
  has "$f" 'an existing test your change breaks'
  has "$f" 'if the suite cannot pass without it, stop as blocked and name it'
done
for f in adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md; do
~~~
3. command: `bash tests/unit-scope-prose.test.sh`
   expect: 1
   The red step: the new rows fail before the persona edits.
4. file: `agents/lead-programmer.md`
   anchor: line matching `- **Unit scope**: edit only the files listed under your dispatch's`
   indent: 0
   before:
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
   after:
~~~
- **Unit scope**: edit only the files listed under your dispatch's `## Affected files`, plus
  `docs/plans/` and `.claude/` bookkeeping. Standing exceptions, in scope without being listed: the
  bump files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally as a file it reads, never a script or test it
  runs (the program it starts, or the script it hands to `bash`, `sh`, `node` or `python3`, such as
  `tests/validate.sh`), which is in scope only when listed; and, in a fix round, a path named in a defect
  of the unit's `.fail` record or listed under its fix contract's `## Affected files`. A path listed under
  the contract's `## Do NOT touch` is out of scope even when a standing exception covers it. Any other
  change you believe is needed (a glossary entry, a README line, an ADR, a caller outside the list, an
  existing test your change breaks) goes in your report under `Proposed out-of-scope changes:` and is not
  applied; if the suite cannot pass without it, stop as blocked and name it.
~~~
5. file: `adapters/codex/agents/lead-programmer.toml`
   anchor: line matching `- **Unit scope**: edit only the files listed under your dispatch's`
   indent: 0
   before:
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
   after:
~~~
- **Unit scope**: edit only the files listed under your dispatch's `## Affected files`, plus
  `docs/plans/` and `.claude/` bookkeeping. Standing exceptions, in scope without being listed: the
  bump files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally as a file it reads, never a script or test it
  runs (the program it starts, or the script it hands to `bash`, `sh`, `node` or `python3`, such as
  `tests/validate.sh`), which is in scope only when listed; and, in a fix round, a path named in a defect
  of the unit's `.fail` record or listed under its fix contract's `## Affected files`. A path listed under
  the contract's `## Do NOT touch` is out of scope even when a standing exception covers it. Any other
  change you believe is needed (a glossary entry, a README line, an ADR, a caller outside the list, an
  existing test your change breaks) goes in your report under `Proposed out-of-scope changes:` and is not
  applied; if the suite cannot pass without it, stop as blocked and name it.
~~~
6. file: `adapters/cursor/agents/lead-programmer.md`
   anchor: line matching `- **Unit scope**: edit only the files listed under your dispatch's`
   indent: 0
   before:
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
   after:
~~~
- **Unit scope**: edit only the files listed under your dispatch's `## Affected files`, plus
  `docs/plans/` and `.claude/` bookkeeping. Standing exceptions, in scope without being listed: the
  bump files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally as a file it reads, never a script or test it
  runs (the program it starts, or the script it hands to `bash`, `sh`, `node` or `python3`, such as
  `tests/validate.sh`), which is in scope only when listed; and, in a fix round, a path named in a defect
  of the unit's `.fail` record or listed under its fix contract's `## Affected files`. A path listed under
  the contract's `## Do NOT touch` is out of scope even when a standing exception covers it. Any other
  change you believe is needed (a glossary entry, a README line, an ADR, a caller outside the list, an
  existing test your change breaks) goes in your report under `Proposed out-of-scope changes:` and is not
  applied; if the suite cannot pass without it, stop as blocked and name it.
~~~
7. file: `agents/reviewer.md`
   anchor: line matching `  path not listed under the dispatch's`
   indent: 2
   before:
~~~
  path not listed under the dispatch's `## Affected files` and not covered by a standing exception: the
  version-stamp files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally; and, after a FAIL, a path named in a defect of
  the unit's `.fail` record or listed under its fix contract's `## Affected files`. Style preferences and
~~~
   after:
~~~
  path not listed under the dispatch's `## Affected files` and not covered by a standing exception: the
  bump files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally as a file it reads, never a script or test it
  runs (the program it starts, or the script it hands to `bash`, `sh`, `node` or `python3`, such as
  `tests/validate.sh`), which is in scope only when listed; and, after a FAIL, a path named in a defect of
  the unit's `.fail` record or listed under its fix contract's `## Affected files`. A changed path listed
  under the contract's `## Do NOT touch` is a FAIL reason even when a standing exception covers it. Style
  preferences and
~~~
8. file: `adapters/codex/agents/reviewer.toml`
   anchor: line matching `  path not listed under the dispatch's`
   indent: 2
   before:
~~~
  path not listed under the dispatch's `## Affected files` and not covered by a standing exception: the
  version-stamp files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally; and, after a FAIL, a path named in a defect of
  the unit's `.fail` record or listed under its fix contract's `## Affected files`. Style preferences and
~~~
   after:
~~~
  path not listed under the dispatch's `## Affected files` and not covered by a standing exception: the
  bump files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally as a file it reads, never a script or test it
  runs (the program it starts, or the script it hands to `bash`, `sh`, `node` or `python3`, such as
  `tests/validate.sh`), which is in scope only when listed; and, after a FAIL, a path named in a defect of
  the unit's `.fail` record or listed under its fix contract's `## Affected files`. A changed path listed
  under the contract's `## Do NOT touch` is a FAIL reason even when a standing exception covers it. Style
  preferences and
~~~
9. file: `adapters/cursor/agents/reviewer.md`
   anchor: line matching `  path not listed under the dispatch's`
   indent: 2
   before:
~~~
  path not listed under the dispatch's `## Affected files` and not covered by a standing exception: the
  version-stamp files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally; and, after a FAIL, a path named in a defect of
  the unit's `.fail` record or listed under its fix contract's `## Affected files`. Style preferences and
~~~
   after:
~~~
  path not listed under the dispatch's `## Affected files` and not covered by a standing exception: the
  bump files that the project's constitution or merge gate requires every such commit to change (in
  this plugin's own repo: `.claude-plugin/plugin.json`, `package.json` and `CHANGELOG.md`); a path that one
  of the unit's acceptance-criteria commands names literally as a file it reads, never a script or test it
  runs (the program it starts, or the script it hands to `bash`, `sh`, `node` or `python3`, such as
  `tests/validate.sh`), which is in scope only when listed; and, after a FAIL, a path named in a defect of
  the unit's `.fail` record or listed under its fix contract's `## Affected files`. A changed path listed
  under the contract's `## Do NOT touch` is a FAIL reason even when a standing exception covers it. Style
  preferences and
~~~
10. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.192 to 0.31.193 if rp-u1 runs first).
11. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Unit scope never exempts a criterion-executed path (rp-u1, VERSION).** agents/lead-programmer.md, agents/reviewer.md and their codex and cursor ports: the acceptance-criteria exception now covers only a file a criterion reads, never a script or test it runs (such as tests/validate.sh), which is in scope only when listed; a path under the contract's `## Do NOT touch` is out of scope even when a standing exception covers it; "version-stamp files" is now "bump files" (CONTEXT.md's Version-stamped file is a different thing). lead-programmer: an existing test the change breaks is proposed under `Proposed out-of-scope changes:`, with a blocked stop if the suite cannot pass without it. tests/unit-scope-prose.test.sh pins it.
~~~
   Replace `VERSION` with the version that edit 10 wrote.
12. command: `node bin/cli.js --update`
   expect: 0
13. command: `bash tests/unit-scope-prose.test.sh`
   expect: 0
14. command: `git add -u && git commit -m "fix(rp-u1): unit scope never exempts a criterion-executed path; Do NOT touch wins"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `hooks/scripts/lib/unit-scope.sh`, `hooks/scripts/writer-scope-gate.sh`, `bin/review-precheck.sh` (st-u1 to st-u3 own them; spec Open Question 1)
- `agents/orchestrator.md`, `adapters/codex/agents/orchestrator.toml`, `adapters/cursor/agents/orchestrator.md` (their scope sentences stay; criterion 4)
- `tests/validate.sh` (unit-scope-prose is already registered; criterion 4)

## Acceptance criteria
1. run: `bash -c 'bash tests/unit-scope-prose.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 9 (cursor reviewer port); four rows fail for that file and stdout is `1`.
2. run: `bash -c 'for f in agents/lead-programmer.md agents/reviewer.md adapters/codex/agents/lead-programmer.toml adapters/cursor/agents/lead-programmer.md adapters/codex/agents/reviewer.toml adapters/cursor/agents/reviewer.md .claude/agents/lead-programmer.md .claude/agents/reviewer.md; do tr -s " \n" " " < "$f" | grep -c "never a script or test it runs"; done | tr "\n" " "'`
   exit: 0
   stdout: `1 1 1 1 1 1 1 1 `
   mutation: skip edit 12 (`--update`); the two `.claude/` mirrors print `0`.
3. run: `bash -c 'x(){ awk "/^- \*\*Unit scope\*\*/{p=1} p{print} /stop as blocked and name it\./{exit}" "$1"; }; y(){ awk "/^  path not listed under the dispatch/{p=1} p{print} /^  preferences and\$/{exit}" "$1"; }; cmp <(x agents/lead-programmer.md) <(x adapters/codex/agents/lead-programmer.toml) && cmp <(x agents/lead-programmer.md) <(x adapters/cursor/agents/lead-programmer.md) && cmp <(y agents/reviewer.md) <(y adapters/codex/agents/reviewer.toml) && cmp <(y agents/reviewer.md) <(y adapters/cursor/agents/reviewer.md) && x agents/lead-programmer.md | wc -l && y agents/reviewer.md | wc -l'`
   exit: 0
   stdout: `12` then `9` (two lines)
   mutation: rewrap one line of edit 8's text in `adapters/codex/agents/reviewer.toml`; `cmp` reports a difference and the command exits 1.
4. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u1)" | tail -1); git diff --name-only "$b^..HEAD" -- . ":(exclude).claude" | sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md adapters/codex/agents/lead-programmer.toml adapters/codex/agents/reviewer.toml adapters/cursor/agents/lead-programmer.md adapters/cursor/agents/reviewer.md agents/lead-programmer.md agents/reviewer.md package.json tests/unit-scope-prose.test.sh `
   mutation: also edit `agents/orchestrator.md` in an rp-u1 commit; it joins the list.
5. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u1)" | tail -1); bash hooks/scripts/version-stamp-check.sh "$b^..HEAD" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 10; stdout reads `version-stamp-check: violation touched: yes`.
6. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/unit-scope-prose.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edits 1-2 add the rows; edit 3 runs the test red (exit 1) before the persona edits 4-9.
proof: spec-master applied edits 1 to 13 to a scratch clone of cfb7ddac with a script that requires each `before:` payload to occur exactly once in its file: every payload matched once, edit 3 exited 1, edit 13 exited 0, after committing (with `VERSION` replaced) criteria 1 to 5 printed the stated stdout; adapter-protocol-parity, adapter-fail-tier-pin, adapter-skill-parity, cli-backfill, persona-prose-pins, prompt-diet-pins and writer-tier-consistency stayed green and both codex `.toml` files still parse. validate.sh was not run by spec-master.
chained: no queued contract (qw-u5, qw-u6, st-u1 to st-u4) edits `agents/lead-programmer.md`, any `adapters/` file or `tests/unit-scope-prose.test.sh`; qw-u5 edits 6-7 and st-u2 edit 6 change `agents/reviewer.md` lines 18-27 and 91, outside this unit's lines 34-38, and no line of this unit's `before:` payloads occurs in any queued `before:` payload.
prior-fail: aof-u3 PASSed with the design finding that became aof-u3b; aof-u3b's commit 4a3e8068 wrote today's text, which edits 4 to 9 replace whole. Wrapping is identical in the source and both ports (criterion 3 holds today over the old text).
queued-rule: st-u1's `us_classify` still classes any `run:` path token as `criteria`; amending it is spec Open Question 1, not this unit.
blast-radius: agents/lead-programmer.md:68, agents/reviewer.md:34, adapters/codex/agents/lead-programmer.toml:66, adapters/cursor/agents/lead-programmer.md:65, adapters/codex/agents/reviewer.toml:52, adapters/cursor/agents/reviewer.md:49, tests/unit-scope-prose.test.sh:26 and :32. Line numbers are at cfb7ddac; work from the anchors.
version: .claude-plugin/plugin.json and package.json read 0.31.192 at cfb7ddac; edit 10 adds one to whatever they read when the unit starts.
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2); the bump is what makes `--update` re-render.
commit-message: fix(rp-u1): unit scope never exempts a criterion-executed path; Do NOT touch wins
diagnosis: none
review-packet:
~~~
unit: rp-u1
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
~~~

## Escalation
If a `before:` payload is not found verbatim, stop and report the current text (a unit landed since
cfb7ddac may have rewrapped it). If `node bin/cli.js --update` reports a mirror as diverged, quote it and
stop. If a gate blocks a command, report it and wait. Anything outside "Affected files" goes to your report
as a proposal.
