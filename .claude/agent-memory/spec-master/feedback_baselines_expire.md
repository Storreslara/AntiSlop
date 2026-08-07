---
name: baselines-expire
description: A spec's pre-change baseline is a measurement with an expiry, not a fact — baselines resting on untracked files are the most perishable and need a recovery-source precondition.
metadata:
  type: feedback
---

Every acceptance criterion stating a pre-change baseline must be treated as
perishable, and criteria resting on **untracked** files must additionally name a
recovery source plus a precondition criterion asserting that source still exists
before the unit starts.

**Why:** Step 7 of the skills-library remediation spec was dispatched as unit
#249 with the baseline "8 files, 4 tracked lowercase + 4 untracked uppercase."
By dispatch time only the 4 lowercase remained. Cause: `git stash
--include-untracked` had swallowed the untracked copies two days after the
baseline was measured. Untracked state is invisible to `git log`, so nothing in
the history records the loss, and routine commands (`git stash -u`, `git clean`)
remove it silently with no warning. The unit was unexecutable as written — its
criterion 1 could never be met — and burned a full escalation round-trip.

Recovery detail worth keeping: `git stash -u` does not destroy the files. The
stash becomes a **three-parent** commit whose third parent is a tree of the
stashed untracked files, so `git checkout <third-parent-sha> -- <path>` restores
them exactly. Diagnose it by checking whether the affected directory's mtime
matches a stash's timestamp.

**How to apply:** When authoring or revising any spec in this repo —
1. Re-measure baselines at revision time, not just at authoring time; state the
   date alongside each one.
2. If a criterion depends on untracked content, add an explicit precondition
   criterion (a `git rev-parse --verify` / `git ls-tree | grep -c` pair against
   the recovery source) so a stale baseline surfaces as a clean precondition
   failure instead of a mid-flight escalation.
3. Prefer specs that *end* the untracked state — once tracked, the whole class
   of silent loss is gone, which is often an unstated second reason the work is
   worth doing.

Pairs with [[criteria-must-be-shell-validated]] and the sibling rule that every
criterion needs a **negative control**: run it against the pre-change tree and
confirm it fails there. Two of Step 7's criteria (`find -iname 'skill.md'` and
`git ls-files | wc -l`) measured identically before and after, so they could not
distinguish a finished unit from an untouched one — caught only by mutation
testing in a throwaway worktree.
