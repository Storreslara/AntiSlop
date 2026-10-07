Unit: demo-2

## Objective
`agents/demo.md` carries the new line and the version is bumped. Done = every criterion below passes.

## Retrieval
GitHub issues, repo example/demo. This unit: `gh issue view 2 --repo example/demo`.

## Affected files
- `agents/demo.md` (anchor: line matching `old line`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)

## Ordered edits
1. file: `agents/demo.md`
   anchor: line matching `old line`
   indent: 3
   before:
   ~~~
   old line
   ~~~
   after:
   ~~~
   new line
   ~~~
2. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after: `- demo: new line in the demo persona (0.2.0)`
3. command: `node bin/cli.js --update`
   expect: 0

## Do NOT touch
- `docs/adr/` (any file)
- `skills/to-tickets/SKILL.md`

## Acceptance criteria
1. run: `grep -c 'new line' agents/demo.md`
   exit: 0
   stdout: `1`
   mutation: revert edit 1; stdout becomes `0`.
2. run: `bash hooks/scripts/version-stamp-check.sh HEAD~1..HEAD`
   exit: 0
   stdout: `ok`
   mutation: skip the plugin.json bump; stdout shows `violation`.

## Pre-resolved context
tdd: no documentation-only change
blast-radius: agents/demo.md:1 (the edited line)
version: `.claude-plugin/plugin.json` 0.1.0 to 0.2.0
version: `package.json` 0.1.0 to 0.2.0
commit-message: docs(demo-2): add the new line (#2)
diagnosis: none
