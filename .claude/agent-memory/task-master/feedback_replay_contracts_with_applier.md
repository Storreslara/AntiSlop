---
name: replay-contracts-with-applier
description: Slicing pitfalls found writing the blf-1..8 contracts: backticks in run lines, vacuous empty-loop criteria, mutation criteria that pass at HEAD, and the scratch-applier replay that catches them.
metadata:
  type: feedback
---

Replay every contract mechanically before handing it off: a small script that parses `## Ordered edits`, applies each before/after or insert-after to a scratch `git worktree` of HEAD (asserting each anchor counts 1), runs the command items, then runs every criterion and compares exit and the first backticked `stdout:` token. Run it once pre-edit (to see which criteria are red) and once per `skip edit N` mutation. It caught: a wrong hunk count, a stale `.claude` path count, and a mutation that really printed 14 not 2.

**Why:** the guard (`contract-guard.js`) only scores shape, 7/7 says nothing about whether the payloads apply or the criteria are red-then-green.

**How to apply:**
- An inline-code `run:` cannot contain a backtick: to count a phrase that quotes backticked text, use `grep -E` with `.` standing for each backtick (and `[|]` for a literal pipe). Anchors with inner backticks must pick a backtick-free substring of the line.
- A per-commit loop over a unit's commits prints `0` and passes when the unit has no commit yet: lead every such criterion with `L=$(...); test -n "$L" || { echo no-unit-commit; exit 3; };`.
- A mutation criterion that edits a doc and runs a NEW test file is vacuous at HEAD (missing file also exits 1): count the test's own `FAIL <doc>` line instead, in a `git worktree add --detach` scratch copy.
- Serial stamped units: later units anchor on entry text, never `CHANGELOG.md:7`, because an earlier unit prepends an entry.
- A `--update --dry-run` filter must be checked against one deliberately stale scratch run (it printed `would be rewritten.` and `would be updated (no local edits detected)`).
