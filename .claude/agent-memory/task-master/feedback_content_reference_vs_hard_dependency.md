---
name: feedback-content-reference-vs-hard-dependency
description: When slicing steps that reference another step's yet-to-exist content (e.g. a pointer step naming a heading a different step creates), don't default to a hard "Depends on" sequencing dependency — check whether the acceptance criteria actually require the referenced content to already exist.
metadata:
  type: feedback
---

Observed 2026-07-21 (issue #89 re-slice, subagent-background-self-wake-protocol
plan): Steps 3-4 (one-line pointers in `agents/reviewer.md` /
`agents/lead-programmer.md`) both textually reference a new section Step 1
creates in `templates/persona-protocol.md`. The orchestrator's dispatch
message explicitly asked me to "confirm from the spec whether that's a hard
sequencing dependency or just a content reference" rather than assuming
either default.

Resolution: it was a content reference, not a hard dependency. Each pointer
step's own acceptance criteria (`grep -qi "synchronous\|foreground\|...`)
only check the pointer step's OWN file — nothing cross-checks that Step 1's
section actually exists yet, and the spec gave an exact suggested heading/
wording up front, so the pointer step's author doesn't need to read Step 1's
landed output to write consistent text. I tagged Steps 1-4 with `Depends
on: none` (all independently gradable / parallelizable) and only made Step 5
(the version bump) hard-depend on all four being merged, since Step 5's
acceptance criteria literally read file content Steps 1-4 produce.

**Why:** defaulting every content-adjacent step to a hard dependency chain
needlessly serializes work that could be parallelized, which slows down
execution for no correctness benefit. Defaulting the other way (assuming no
dependency) without checking is equally wrong when a later step's acceptance
criteria genuinely do read the earlier step's output.

**How to apply:** before writing a `Depends on / blocked by` line, ask
specifically: does THIS step's acceptance-criteria command read/verify
content that only exists after the other step lands? If yes → hard
dependency, name the other issue number and require it merged (not just
filed), same discipline as [[cross_plan_version_coordination]]'s
merged-vs-open distinction. If the reference is purely textual/topical
(pointing at a heading name, a concept, a convention) and the acceptance
check doesn't cross-verify it, it's a content reference — note it in the
dispatch prompt so the executor uses consistent terminology, but don't
serialize the units over it.
