Unit: demo-1-scribe

## Objective
Record the new term.

## Glossary edits
1. file: `CONTEXT.md`
   heading: `Demo term`
   text: `A demo term used for testing.`

## ADR
none

## Close conditions
- issue: #123
- task-id: demo-1
- marker first line: "PASS demo-1 2026-10-06T00:00:00Z commit: none criteria: demo"

## Do NOT touch
- `agents/` (any persona file)
- `hooks/` (any script)

## Acceptance criteria
1. run: `grep -c 'Demo term' CONTEXT.md`
   exit: 0
   stdout: `1`
