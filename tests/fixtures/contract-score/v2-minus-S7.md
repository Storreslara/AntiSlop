Unit: demo-3

## Objective
Record the new term.

## Retrieval
GitHub issues, repo example/demo. This unit: `gh issue view 3 --repo example/demo`.

## Glossary edits
1. file: `CONTEXT.md`
   heading: `Demo term`
   text: `A demo term used for testing.`

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue: #3
- task-id: demo-3
- marker first line starts with: "PASS demo-3 "

## Do NOT touch
- `agents/` (any persona file)
- `hooks/` (any script)

## Acceptance criteria
1. run: `grep -c 'Demo term' CONTEXT.md`
   exit: 0
   stdout: `1`
   mutation: remove the entry; stdout becomes `0`.

If any item cannot be applied exactly, STOP and report a spec gap.
