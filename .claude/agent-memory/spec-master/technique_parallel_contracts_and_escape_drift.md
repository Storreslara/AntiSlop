---
name: technique-parallel-contracts-and-escape-drift
description: Parallel fast-path contracts need explicit-path staging + `git diff --quiet HEAD -- <own files>`; authored `—` escapes become literal em dashes; and a proof-of-a-proof `mutation:` line must leave the inner criterion green.
metadata:
  type: feedback
---

Two traps hit while writing the epfc (round-3) plan, 2026-10-13.

1. **Parallel units.** Round-2 contracts ended with `git status --porcelain --untracked-files=no | wc -l` = 0.
   Under parallel dispatch in one tree, a sibling's in-flight edit breaks that. Use explicit-path
   `git add <own files>`, then `git diff --quiet HEAD -- <own files>` (expect 0), plus an `index.lock` retry note.
   Also verify each unit ALONE (one worktree per unit cherry-picked onto the criteria commit). That is the
   parallel-safety evidence, not the combined run.
2. **Escape drift.** A `—` escape I typed in a heredoc fragment AND in a Write-tool plan body both landed
   as a literal U+2014. Before-blocks then match nothing (apply.py count 0). Fix with python `'\\u2014'`,
   then `grep -c 'u2014'`.

3. **Layered proofs (round 4, 2026-10-13).** When criterion B is a mutation proof OF criterion A's script,
   B's `mutation:` line must use a mutant that leaves A green (e.g. delete the mutant block), or A reports
   it first and B's stated message is never printed. Two of my first-draft lines were wrong this way;
   observe every non-obvious `mutation:` line in the prototype.

**Why:** both are silent until a unit runs. A contract whose before-block holds the wrong byte makes a haiku
implementer stop on "spec gap".

**How to apply:** after writing any plan, extract every before/after pair from the plan file itself, apply
them to a fresh worktree, and run all criteria there. Related: [[technique-contract-guard-r6-bullet-shape]],
[[verify-own-criteria-nonvacuous]].
