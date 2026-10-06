Unit: demo-1

## Objective
`agents/demo.md` carries the new line and the version is bumped. Done = every criterion below passes.

## Retrieval
GitHub issues, repo example/demo. This unit: `gh issue view 1 --repo example/demo`.

## Affected files
- `agents/demo.md` (anchor: the line `old line`)
- `CHANGELOG.md` (anchor: top of the file)

## Ordered edits
1. file: `agents/demo.md`
   anchor: the line `old line`
   before: `old line`
   after: `new line`
2. file: `CHANGELOG.md`
   anchor: the first heading
   insert-after: `- demo: new line in the demo persona (0.2.0)`
3. command: `node bin/cli.js --update`
   expect: 0

## Do NOT touch
- `docs/` (any file)
- `skills/` (any file)

## Acceptance criteria
1. run: `grep -c 'new line' agents/demo.md`
   exit: 0
   stdout: `1`
2. run: `bash hooks/scripts/version-stamp-check.sh HEAD~1..HEAD`
   exit: 0
   stdout: `ok`
   mutation: drop the version bump; stdout shows `violation`.

## Pre-resolved context
tdd: no documentation-only change
blast-radius: agents/demo.md:1 (the edited line)
version: `.claude-plugin/plugin.json` 0.1.0 to 0.2.0
version: `package.json` 0.1.0 to 0.2.0
commit-message: docs(demo): add the new line
diagnosis: none
