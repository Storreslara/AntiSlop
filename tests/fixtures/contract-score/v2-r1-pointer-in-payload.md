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
   new line as specified
   ~~~
2. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   before: `- old`
   after: `- demo: see the plan for the new line (0.2.0)`
