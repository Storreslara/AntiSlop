---
name: baselines-expire
description: A spec's pre-change baseline is a measurement with an expiry, not a fact — untracked-file baselines, absolute byte-pins, and live-sweep classification tables are the most perishable; each needs a named re-derivation route, not a recorded number.
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

**Fourth instance — and the general fix: pin the COMMIT, not the date
(2026-08-14, gh288-2, C2.3, 2-FAIL-cap escalation).** ADR 0020 asserted "110
files as of today (2026-08-14)" for a repo-wide grep. It hit the 2-FAIL cap
because a *date* does not identify a tree, and every symptom cascaded from
that one choice: the number drifted (109 at the authoring commit -> 124 three
days later); an `--exclude-dir` flag was needed at all (marker files exist
only in a live tree); and the count became tool-sensitive (see
[[grep-is-wrapper-shadowed-inline]]). Rewriting the measurement as a
**commit-pinned `git grep -l <pat> <sha> | wc -l`** collapsed all three at
once — `git` is not wrapper-shadowed, gitignored paths are untracked so no
exclusion flag is possible *or* needed, and a commit is immutable so the
number reproduces on any day, from a fresh clone, dirty tree or clean.

**How to apply:** when a criterion counts anything in a live, growing corpus,
reach for a commit pin *before* reaching for the repo's older advice to
"re-measure at execution time" (`docs/plans/2026-08-09-agent-auditor-persona.md`
Step 12). Re-measuring is the right pattern only when the criterion must track
the present (runtime, RSS, a merge gate's colour); when it is *evidence for an
argument* — as a false-positive-surface count is — the pin is strictly better,
because it makes re-measurement return the same number forever instead of
telling the reader to expect drift. Bonus: pinning to the document's OWN
authoring commit repairs internal date coherence for free, and lets a
sibling measurement's stale count be restored rather than re-dated. Always
add a non-vacuity control clause: substituting a different SHA must yield a
different number, or the pin is decorative.

**Fifth instance — a CLASSIFICATION expires, not just a count, and it has two
failure modes that look identical (2026-09-24, hcb-prose-history / #473).** A
criterion held a literal file-keyed table classifying every hit of a live
`git grep` sweep, closed in both directions (unlisted hit-bearing file = red,
listed zero-hit file = red). Authored against 13 files; **18** by dispatch, 19
days of sibling commits later. Two distinct defects present as the same red:
(a) *the category set is too narrow* — a hit no bucket admits, fixed by widening
the escapes; (b) *the repo moved* — a hit every bucket admits but no row lists,
whose correct remedy is emphatically **not** a new category. Here zero of four
late arrivals needed one, and **two of the four came from the same slice's own
sibling units** — a classification authored in one unit and asserted in another
is a cross-unit coupling with a shelf life in commits, not weeks.

**How to apply:** (1) never let a closure check over a live sweep ship without
an explicit escalation route in the criterion text saying a new count is the
criterion working and an unclassified member is a ruling to request, never a
bucket to invent; (2) state the expected-count line as a *dated record, not a
pin*, twice over if you re-measure at amendment time; (3) resist "it belongs to
another spec" as a classification — it is a statement about **authority**, not
category, and the fix is a ruling, not a deferral (check whether the other spec
is even still in flight: here all six of its units had already passed, so there
was nothing to defer *to*); (4) **choose the remedy by artifact kind, not by
uniformity** — append-only dated notes protect *dated historical records* whose
value is saying what was true then (ADR-0029's reasoning), while a living
artifact (agent memory) must be **corrected in place**, because annotating it
leaves a false sentence in force for the next reader. Two files carrying the
identical stale clause correctly get different remedies, and a reviewer flagging
that asymmetry as inconsistency has the rule backwards.

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
