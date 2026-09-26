---
name: context-glossary-prexisting-red
description: RESOLVED (commit 00ee21e) — context-glossary-links.test.js false-positived on backtick-wrapped [[...]] syntax examples in CONTEXT.md; extractLinks() now excludes backtick-delimited bracket matches
metadata:
  type: project
---

`tests/context-glossary-links.test.js` was red at HEAD (9294196, before this
fix) because its `extractLinks()` regex matched ANY `[[...]]`, including the
literal `` `[[term-not-yet-defined]]` `` / `` `[[…]]` `` syntax examples
inside CONTEXT.md's own "dangling link" glossary entry — already
backtick-wrapped, which proved the checker had no code-span exclusion at all
(not just a wording problem in the entry).

**Fix (commit 00ee21e, unit fix-dangling-link-example-false-positive):**
hardened `extractLinks()` in `tests/context-glossary-links.test.js` to skip a
`[[...]]` match immediately preceded and followed by a backtick. Verified via
grep that no genuine cross-reference link in either CONTEXT.md or
docs/harness-glossary.md is ever backtick-wrapped today (~200 real links
checked), so the exclusion introduces no false-negative currently. Added two
regression tests: one proving the code-span example is suppressed, one
proving the identical text unwrapped is still caught. `bash tests/validate.sh`
now exits 0 again.

**Residual limitation (accepted, not fixed):** a genuinely dangling link that
someone DID wrap in backticks would now be silently skipped — verified this
by manual mutation. Acceptable because no real link is ever written that way
in this project's convention; if that convention changes, this exclusion
would need revisiting.

**Why kept:** future units may still find this test red if a worktree check
lands on a pre-fix commit — this memory documents that the fix already
landed at 00ee21e so a fresh red result there is a NEW regression, not this
same known issue recurring. See
[[worktree-fix-then-narrow-commit-live-tree]] for the worktree-verification
technique used to confirm pre-existing-vs-caused-by-you.
