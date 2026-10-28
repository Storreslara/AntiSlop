---
name: technique-anchored-mutation-lines
description: When a contract cannot carry a tested payload, fix `# mut:<name>` anchor comments on the exact guard lines and make one criterion delete/move each in a scratch copy, so writer-authored tests cannot pass vacuously.
metadata:
  type: feedback
---

When a contract specifies behaviour rather than a byte-exact payload (no implementation to copy from), the
writer authors both the code and its tests, so "suite exits 0" proves little. The fix used for rfp-u2c
(2026-10-28):
- Mandate each security or ordering check as ONE line carrying an anchor comment (`# mut:token`,
  `// mut:detail`). Use single-line `if …: return refuse(...)` shapes so deleting the line is syntactically
  safe, and use two adjacent anchored lines for an ordering bug, so awk can swap them.
- One criterion copies the files to `mktemp -d`, applies each mutation (sed delete, sed append, or awk move),
  and prints `name=red` only if the file changed AND the suite failed AND the named case printed FAIL.
  Otherwise it prints `noanchor`, `green` or `other`. Prefix it with `base=pass`, which requires the
  unmutated suite to be all-pass with no SKIP.
- Run the sed/awk on a dummy file with the anchor lines before handoff. The `\&\&` inside a sed `a` text
  inside `bash -c '…'` survives as `&&`.

**Why:** label-ui's 3 FAILs were all write paths the writer's own tests never exercised. A mutation matrix
the writer cannot weaken without visibly removing an anchor is the cheapest non-vacuous check.
**How to apply:** for any contract without a payload, especially security gates and UI invariants. Also see
[[technique-sentinel-stub-single-impl-proof]] and [[feedback-verify-own-criteria-nonvacuous]].
