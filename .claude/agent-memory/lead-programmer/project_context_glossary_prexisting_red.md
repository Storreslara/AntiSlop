---
name: context-glossary-prexisting-red
description: tests/context-glossary-links.test.js is red at HEAD (9294196), pre-existing and unrelated to item05-3 — a literal `[[...]]` glossary-syntax example in CONTEXT.md's own "dangling link" entry mis-parses as a real dangling link
metadata:
  type: project
---

`tests/context-glossary-links.test.js` fails `bash tests/validate.sh`
(3 FAIL lines) at commit 9294196 (0.31.89, before item05-3 started) — verified
via a detached `git worktree` at that commit, running the test file directly.
CONTEXT.md's own "dangling link" glossary entry (added by the item03/item04
consolidated-catch-up commit a9c1040) uses literal `[[term-not-yet-defined]]`
and `[[…]]` as illustrative syntax examples; the checker doesn't distinguish
these from real dangling links and flags them.

**Why:** this means `bash tests/validate.sh` cannot be relied on to exit 0
right now for ANY unit, independent of that unit's own correctness — check
with a worktree at the unit's own base commit before assuming a red suite is
something your unit caused.

**How to apply:** CONTEXT.md is scribe's owned file, not
lead-programmer's — don't fix this yourself inside an unrelated unit's scope;
report it as a pre-existing, cross-cutting blocker (with the worktree
evidence) and let the orchestrator dispatch a dedicated fix. See
[[worktree-fix-then-narrow-commit-live-tree]] for the worktree-verification
technique.
