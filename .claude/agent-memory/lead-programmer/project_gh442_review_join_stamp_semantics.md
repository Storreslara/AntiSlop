---
name: project_gh442_review_join_stamp_semantics
description: gh442 (Step 3 M1+M2+M3, review-join stamp semantics) technique notes - ls-glob pipefail abort trap, OR-widening a branch guard safely, Set A gate blocks read-only Bash text too
metadata:
  type: project
---

Unit gh442 (plan `docs/plans/2026-09-09-fable-gate-audit-remediation.md` Step 3)
landed at commit `0f8f11b`: M1 (unconditional review-join stamp + recorded
prior=pass), M2 (advisory stamp variant, `JOIN_ADVISORY_UNITS`, never
satisfies flag-clearing), M3 (bounded, oldest-first pending-review flag
clearing). All required suites + `tests/validate.sh` green in a pristine
detached worktree at the unit's own commit (CC1 + CC3).

Three reusable gotchas from this unit:

1. **`ls <glob>* | wc -l` aborts under `set -e -o pipefail` when the glob has
   zero matches.** Bash passes the literal unexpanded pattern to `ls` when
   nothing matches; `ls` exits nonzero on stderr, and pipefail propagates that
   through `wc -l`'s otherwise-0 exit, killing the whole test script mid-run
   with no visible FAIL line (subsequent test cases just silently never run).
   Fix: count via a `shopt -s nullglob; arr=( ... ); shopt -u nullglob;
   echo "${#arr[@]}"` helper instead of `ls | wc -l`, exactly like this
   codebase's existing `stamp_count()`/`pending_flags` idiom elsewhere.

2. **Widen an existing `elif` guard with a new OR-disjunct, never replace it,
   when a new stamp category (M2's advisory) needs to skip the "else" block
   without disturbing the OTHER existing paths that already reach that
   elif.** The temptation was to reframe the condition as
   `[ "${#JOIN_UNSATISFIED_UNITS[@]}" -eq 0 ]` (cleaner-looking), but that
   silently broke the pre-existing "mixed satisfied+unsatisfied" test
   (`join-concurrent-liveness`, gh425): with the reframe, ANY unsatisfied
   unit routes to the block-path even when another unit in the same stamp
   set is already satisfied. The safe move was `[ existing-condition ] ||
   [ new-condition ]` - a strict OR-superset of the original, so every
   already-passing case still enters via its original disjunct, and only the
   genuinely-new case (all stamps advisory/failopen, zero unsatisfied) newly
   enters via the added one. Re-derive every existing test scenario against
   the new combined truth table before committing to a "simpler" rewrite.

3. **`harness-integrity-gate.sh`'s Set A block fires on *any* Bash command
   text containing `.claude/persona-config.json`, including read-only
   `git diff <that path>` or `git show HEAD:<that path>`** - not just writes.
   It's a textual scan (ADR-0025), so it can't distinguish read from write.
   Confirming the CC1 fileHashes-only delta therefore can't be done via a
   Bash `git diff` naming that path; trust `bin/cli.js`'s own printed
   "updated (no local edits detected)" / "already current" status lines
   instead, as prior units (see
   [[project_harness_integrity_gate_persona_config_commit]]) already do for
   the commit step.

See also [[project_gh423_config_drift]] and
[[project_harness_integrity_gate_persona_config_commit]] for adjacent Set A/
CC1/CC2 mechanics on the same file.
