---
name: dispatch_hygiene_mutation_commands
description: Extract mutation-control reproduction commands verbatim from spec docs, not by retyping
metadata:
  type: feedback
---

## Dispatch hygiene: shell-escaping trap in mutation-control reproduction commands

**Rule:** Mutation-control reproduction commands in dispatch text should be quoted verbatim from the canonical spec doc, not retyped. When retyped, shell-escaping errors are easy to introduce and produce a silent no-op mutant that "passes" while testing nothing.

**Why:** 
Unit #270's dispatch text contained a broken AC1.5 mutation command: single-escaped `\t\n` in a double-quoted sed argument reached sed as literal TAB/LF bytes (via shell's `$'...'` ANSI-C quoting context), causing the mutation to silently fail to apply. The gate remained unchanged, the suite exited 0 with no FAILs, and the acceptance criteria appeared to pass — but the test proved nothing. The canonical spec doc had the correct form (doubled backslashes), but the dispatch message drifted during copying. Both forms were empirically tested: the doc's version mutated the target correctly (6 FAILs, all expected); the single-escaped form was a silent no-op (0 FAILs, zero effect observed).

**How to apply:** 
When writing dispatch text for a unit that includes a mutation-control reproduction command, extract the exact command from the canonical spec document rather than retyping it. Mutation-control commands are inherently shell-sensitive, and even small differences in quoting context (double-quoted vs. single-quoted, ANSI-C quoting context, BRE vs. extended regex escaping) can silently disable the mutation. If uncertain about whether the copied text is correct, verify by running both forms empirically (as the reviewer did for unit #270) and checking that only the intended form produces test failures. Record the command in the case's header or step notes byte-for-byte so future readers can verify it against the source.

**Bonus validation:** The spec's own instruction that the `grep -n "meta="` inspection line "is part of the control, not decoration" makes this class of no-op catchable — a mutation that doesn't actually change the target can be detected by re-inspecting the variable after the mutation is claimed to have applied.
