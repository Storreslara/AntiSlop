# Dispatch contract examples

Contract examples (sample lead contracts), a legacy issue-body layout and a scribe contract. `tests/contract-examples.test.js` scores them under `--rubric=v2` and runs `bin/contract-guard.js` over the issue-body layout; the marked blocks are read by those markers, so keep them intact.

<!-- lead-contract-example:begin -->
```
Unit: demo-7

## Objective
`agents/demo.md` documents the quiet flag; version 9.9.1; mirrors refreshed.

## Retrieval
GitHub issues: `gh issue view 999 --repo owner/repo`.

## Affected files
- `agents/demo.md` (anchor: line matching `## Flags`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "9.9.0",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. file: `agents/demo.md`
   anchor: line matching `## Flags`
   insert-after: `- quiet: suppresses the banner line.`
2. file: `.claude-plugin/plugin.json` (version 9.9.1)
   anchor: line matching `"version": "9.9.0",`
   before: `"version": "9.9.0",`
   after: `"version": "9.9.1",`
3. file: `package.json` (version 9.9.1)
   anchor: line matching `"version": "9.9.0",`
   before: `"version": "9.9.0",`
   after: `"version": "9.9.1",`
4. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after: `**Demo quiet flag (demo-7, 9.9.1).** Documents quiet.`
5. command: `node bin/cli.js --update`
   expect: 0
6. command: `git add agents/demo.md CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "docs(demo-7): quiet flag (9.9.1) (#999)"`
   expect: 0

## Do NOT touch
- `agents/other.md`
- `skills/pathfinder/SKILL.md`

## Acceptance criteria
1. run: `grep -c 'suppresses the banner' agents/demo.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 1; stdout `0`.
2. run: `bash hooks/scripts/version-stamp-check.sh HEAD~1..HEAD`
   exit: 0
   stdout: `version-stamp-check: ok`
   mutation: skip edit 2; the line no longer reads `ok` (the script reads only plugin.json).
3. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;process.exit(a===b?0:1)" && echo version-sync: ok`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 3; nothing prints, exit 1.

## Pre-resolved context
tdd: no prose-only edit
blast-radius: agents/demo.md:12
commit-message: docs(demo-7): quiet flag (9.9.1) (#999)
review-packet:
~~~
unit: demo-7 (#999)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
```
<!-- lead-contract-example:end -->

<!-- issue-body-layout-example:begin -->
```
Step 3 of the demo slice (umbrella #998). Stamped: yes.

Suggested model: haiku

Depends on / blocked by: #997.

## Dispatch contract
~~~~
<the lead contract above, `Unit: demo-7` first>
~~~~
```
<!-- issue-body-layout-example:end -->

<!-- scribe-contract-example:begin -->
```
Unit: demo-8

## Objective
CONTEXT.md defines "slice state".

## Retrieval
GitHub issues: `gh issue view 998 --repo owner/repo`.

## Glossary edits
1. file: `CONTEXT.md`
   heading: `## Glossary`
   text: `**slice state** - the dispatchable-or-held table a slicing report ends with.`

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue #998
- task-id: demo-8
- marker first line: "PASS demo-8 "

## Do NOT touch
- `agents/`
- `docs/adr/`

## Acceptance criteria
1. run: `grep -c 'slice state' CONTEXT.md`
   exit: 0
   stdout: `1`
   mutation: skip the glossary edit; stdout `0`.
2. run: `node tests/context-glossary-links.test.js`
   exit: 0
   stdout: `All context-glossary-links checks passed.`
   mutation: add the link `[[no such term]]` to the entry; the test fails.
3. run: `node tests/ubiquitous-language.test.js`
   exit: 0
   stdout: `passes all 4 structural/distinguishability checks`
   mutation: set `UL_TEST_MUTATE=1`; the test exits non-zero (it checks skills/ubiquitous-language/SKILL.md, not the entry).
   proof: `UL_TEST_MUTATE=1 node tests/ubiquitous-language.test.js` exits non-zero.

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap.
```
<!-- scribe-contract-example:end -->
