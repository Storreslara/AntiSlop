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

**Second instance — a spec's IMPERATIVES expire too, not just its baselines
(2026-08-11, gh138).** Issue #138 was authored 2026-07-28 and executed
2026-08-11. Two of its instructions were state assertions wearing an imperative's
clothes, and both had gone false in the interval:
- *"Next free numbers are `0007` and `0008` (`docs/adr/` currently holds
  `0001`–`0006`)"* — by execution time `docs/adr/` held through `0016`, and
  `0007` is a deliberately preserved hole (see
  [[adr-numbering-increment-not-backfill]]). The agent backfilled it as told.
- *"Add entries for Microworld, escalation packet, …"* — **all seven** terms
  already had canonical `CONTEXT.md` entries. The agent appended seven
  near-duplicates; a later pass merged all seven back in place.

The agent was not careless; it trusted the packet over the filesystem, which is
usually correct. The defect is mine: I wrote a countable fact into an imperative
with no re-derivation instruction. **How to apply:** any spec verb carrying an
embedded count, number, or "currently holds / next free / does not yet exist"
must ship with a re-derive-at-execution-time instruction naming the command
(`ls docs/adr/`, `grep -n '^\*\*' CONTEXT.md`), not the answer. Phrase it
"ensure X is present and correct", never "add X" — the two differ exactly when
the packet has aged.

Pairs with [[criteria-must-be-shell-validated]] and the sibling rule that every
criterion needs a **negative control**: run it against the pre-change tree and
confirm it fails there. Two of Step 7's criteria (`find -iname 'skill.md'` and
`git ls-files | wc -l`) measured identically before and after, so they could not
distinguish a finished unit from an untouched one — caught only by mutation
testing in a throwaway worktree.

**Third instance — an absolute byte-pin is a baseline too, and prose reflow
expires it (2026-08-14, gh348-13, C13.2).** Pass 3 pinned three paragraphs of
`agents/orchestrator.md` "byte-identical to `e5b908f`" as an anti-regression
control; Step 13's C13.2 carried that exact absolute-commit pin forward
verbatim. Four days after the pin, a wholly legitimate, unrelated commit
(`697541e`, issue #236, "compress ... to <=110 lines") reflowed the pinned
paragraph's line-wraps — word content unchanged, wrap points moved. Nothing
re-checked the pin's validity between that commit landing and gh348-13's own
dispatch 8 days later, so the criterion was unsatisfiable the whole time and
nobody noticed until a lead-programmer tried to run it. **The fix pattern:**
(1) switch the comparison from raw bytes to whitespace-normalized content
(`tr -s ' \n' ' '` on the extracted paragraph) so wrap-only drift can't
trip it, and (2) re-anchor from the stale absolute commit to a **relative**
pin — "unchanged from the immediate pre-step commit" — which is what the
same document's `C5.2`/`C14.3` already did correctly and is why neither of
them shared this defect. **How to apply:** any criterion pinning prose (or
any text) "byte-identical to `<commit>`" is exactly as perishable as an
untracked-file baseline — treat an absolute-commit content pin as expiring
the moment ANY future commit is allowed to touch that region for unrelated
reasons (formatting passes, line-length compressions), and prefer a relative
"unchanged since the immediately preceding step" pin over an absolute one
whenever the plan spans more than one execution session.
