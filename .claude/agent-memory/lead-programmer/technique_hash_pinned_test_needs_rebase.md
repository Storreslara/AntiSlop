---
name: hash-pinned-test-needs-rebase
description: A test that sha256-pins a code clause against a historical commit fails on any later sanctioned edit to that clause — re-target the pin commit, don't revert the edit or skip the test
metadata:
  type: technique
---

`tests/stop-gate-microworld-skip.test.sh`'s AC-B4a hashed `agents/reviewer.md`'s
"Run the checks yourself" clause against historical commit `09cc304`, to prove
one *specific historical unit* (spec2-unitB) never touched it — see
`docs/plans/2026-08-25-agent-throughput-performance-dampeners.md:756-759`,
"AC-B4 (reviewer untouched — **hard constraint**)". It was scoped to that
one unit's own diff, not an eternal ban on ever editing the clause again.

memdirt-1 made a separately-planned, spec-master-approved edit to exactly that
clause (narrowing the clean-tree PASS precondition), which made AC-B4a FAIL —
collateral damage from a sanctioned change, not a defect in the change itself.

**Why:** two rules that look like they conflict (don't revert your own
sanctioned work vs. don't leave `tests/validate.sh` red) aren't actually in
tension once you see the pin's true scope — it's a snapshot test, not a
standing gate. This is the same shape as [[technique_adr_amend_vs_edit_when_pinned]]
but for a `.sh` test's hash pin instead of an ADR's exact prose.

**How to apply:** before assuming a plan is wrong because an unrelated test
turned red, read what the pin's ORIGINAL acceptance criterion actually scoped
it to (grep the historical plan doc, not just the test file). If it was scoped
to a different unit's diff, re-target the pin to your own new commit (update
both the `git show <sha>` and the check's label string) rather than reverting
your edit or touching the unrelated file it protects. This keeps future
protection against unrelated drift while accepting today's sanctioned change.
