Unit: rp-u6

## Objective
Fix round 3 for rp-u6 (third reviewer FAIL; implementer tier unchanged, the ratchet stays). The code is correct; the only failing check is a defect in the contract. Original criterion 5 in `docs/plans/antislop-review-patches/contracts/rp-u6.md` uses the span `0ed1bb1e^..ef2b4284`, which also takes in commits 28deea63 and 47deb03f that added `rp-u6-fix1.md` and `rp-u6-fix2.md`, so its file list can never match. This contract replaces criterion 5 with the per-commit form over the code commits only. No file other than this contract is changed.

## Retrieval
Fast path, no tracker issue. Fix contract of record for `Unit: rp-u6`; original `docs/plans/antislop-review-patches/contracts/rp-u6.md`, round 1 `rp-u6-fix1.md`, round 2 `rp-u6-fix2.md`. The unit's code commits are 0ed1bb1e, 32e61aae and ef2b4284.

## Affected files
- `docs/plans/antislop-review-patches/contracts/rp-u6-fix3.md` (anchor: line matching `Unit: rp-u6`)

## Ordered edits
1. command: `node bin/contract-score.js --rubric=v2 docs/plans/antislop-review-patches/contracts/rp-u6-fix3.md`
   expect: 0
   stdout: `"score":7`

## Do NOT touch
- `bin/contract-anchors.js`
- `tests/contract-anchors.test.sh`
- `docs/plans/antislop-review-patches/contracts/rp-u6.md`
- `docs/plans/antislop-review-patches/contracts/rp-u6-fix1.md`
- `docs/plans/antislop-review-patches/contracts/rp-u6-fix2.md`

## Acceptance criteria
1. run: `bash -c 'for c in 0ed1bb1e 32e61aae ef2b4284; do git diff --name-only "$c~1..$c" -- . ":(exclude).claude"; done | LC_ALL=C sort -u | paste -sd" "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md bin/contract-anchors.js package.json tests/contract-anchors.test.sh tests/validate.sh`
   mutation: also edit `bin/contract-score.js` in one of the three code commits, or add 28deea63 to the loop; the list gains a path.
   proof: `git diff --name-only 0ed1bb1e^..ef2b4284 -- . ":(exclude).claude"` run in the scratch checkout printed the two `contracts/rp-u6-fix` paths in addition.
2. run: `bash -c 'git log --format="%H %s" 0ed1bb1e^..ef2b4284 | /usr/bin/grep -cE "^[0-9a-f]+ [a-z]+\(rp-u6\): "'`
   exit: 0
   stdout: `3`
   mutation: drop the `(rp-u6): ` scope from one code commit subject; stdout is `2`.
3. run: `bash -c 'for c in 0ed1bb1e 32e61aae ef2b4284; do git log -1 --format=%s "$c" | /usr/bin/grep -cE "^[a-z]+\(rp-u6\): "; done | sort -u'`
   exit: 0
   stdout: `1`
   mutation: add 28deea63 to the loop; its subject is scoped to the plan, so the output gains a `0` line.
4. run: `bash -c 'git diff --name-only ef2b4284..HEAD -- bin/contract-anchors.js tests/contract-anchors.test.sh | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `bin/contract-anchors.js` in a commit after ef2b4284; stdout is `1`.

## Pre-resolved context
tdd: no contract-only change; criteria 1 to 4 are runnable on the existing history
blast-radius: none
supersedes: this contract's criterion 1 replaces original criterion 5 of `rp-u6.md` (the span `0ed1bb1e^..ef2b4284` and its expected list, lines 395 to 397 of that file), and it supersedes `rp-u6-fix2.md`'s statement that original criteria 1 to 8 still hold, for criterion 5 only. Original criteria 1 to 4 and 6 to 8 still hold as fix 2 left them. Fix 2 criterion 9 is the same per-commit form over 32e61aae..HEAD and is unchanged.
reuse: the re-review relies on the results already confirmed: fix 1 criteria 1 to 7, 13 and 14, and fix 2 criteria 1 to 15. It re-runs only criteria 1 to 4 here.
version: no stamped file is touched; no bump, no CHANGELOG entry, no `--update`.
commit-message: docs(antislop-review-patches): fix contract rp-u6-fix3, original criterion 5 becomes the per-commit form (rp-u6)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
fix-of: 2026-10-27, the third FAIL block of the unit's fail record
review-packet:
~~~
unit: rp-u6 (fix 3)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
