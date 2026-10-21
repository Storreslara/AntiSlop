---
name: technique-range-grep-unit-id-collision
description: Range criteria `git log --grep="(<unit>)"` also match docs commits that mention the unit in parentheses; tail -1 then picks a far older commit
metadata:
  type: feedback
---

A range criterion of the form `b=$(git log --format=%H --grep="(<unit>)" | tail -1)` matches ANY commit
message containing the parenthesised id, including spec-master's own docs commits ("Step 8 (rp-u7) from
the qw-u5 review", c02b286a). `tail -1` then names that old commit and the changed-file list spans
everything since. Found 2026-10-21 by running rp-u7's criteria on a chained clone.

**Why:** the criterion passes or fails for reasons unrelated to the unit, and the reviewer cannot tell.

**How to apply:**
- Before committing a contract, run `git log --oneline --grep="(<unit>)"` on the real repo: it must print
  nothing (the unit has not landed yet).
- Never put a parenthesised unit id in a docs commit message; write "Step 8, rp-u7".
- Prefer `--grep="^[a-z]*(<unit>): "` in new range criteria (conventional-commit subjects only).
See [[verify-own-criteria-nonvacuous]] and [[technique-prove-contracts-on-a-clone]].
