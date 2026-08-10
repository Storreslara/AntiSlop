---
name: feedback-verify-own-criteria-nonvacuous
description: Before finalizing a spec, RUN each acceptance criterion against the current tree — a criterion that already passes (or trivially passes) is vacuous and gates nothing
metadata:
  type: feedback
---

Run every acceptance criterion I author against the working tree *before*
handing the spec off, and confirm it is currently RED. A criterion that is
already green, or that greps for a string no target file contains, gates
nothing and will be reported as satisfied without the work being done.

**Why:** on the 2026-08-07 commit-anchored-markers spec I wrote
`! grep -rq '<old printf>' hooks/scripts/ commands/ skills/` as a "the old
format is gone" check across four files. Running it revealed the pattern
matched only ONE of the four: one file wraps the same printf across two lines
(so a single-line grep misses it) and another spells a different variant. Three
of the four files could have been left completely un-updated and the criterion
would still have passed. Caught only by executing it, exactly the failure
constitution P1 ("Verify, don't assume") names. Same shape as
lead-programmer's own `feedback_grep_acceptance_line_wrap` memory — but I am the
one who AUTHORS criteria, so the check belongs on my side first.

**How to apply:** prefer one criterion per file over one recursive grep across
a directory. For each, run both halves — the negative (`! grep old`) and the
positive (`grep new`) — and assert the positive currently returns 0 matches.
Multi-line/wrapped source strings are the specific trap: grep is line-oriented,
prose files wrap, so never grep a token longer than a plausible line.
**Second trap - self-reference (2026-08-09, agent-auditor round-2 follow-up):**
when the artifact under test IS the plan document, a whole-file `grep` in a
criterion *counts the criterion's own text*. Writing "the broken pattern is gone:
`! grep -qF '<pattern>' plan.md`" is unsatisfiable the moment the plan quotes
that pattern to explain the defect - and the mirror-image "`grep -c '<marker>'
>= 2`" is already green for the same reason. I hit both, then hit them AGAIN on
the first repair attempt (predicted 3 and 0, measured 4 and 3). The fix is to
scope the grep to the target section, not the file:
`sed -n "/^### <heading>/,/^### /p" plan.md | grep -qF ...`, which structurally
excludes the section the criterion lives in. Also check the marker string is not
already present in the target range for unrelated reasons - `vacuous` was.

**How to apply (self-reference):** any criterion whose target file is the spec
itself must be section-scoped or it is broken by construction. Predict the
expected count, then RUN it; if the measurement disagrees with the prediction,
the criterion is counting itself.

**Third trap - criteria-only sweeps miss PROSE premises (2026-08-10, microworld
dashboard D1).** I ran every criterion in a finalized plan against the tree and
caught one defect (an inherited unsatisfiable grep) — then the orchestrator, doing
a pre-dispatch check, found a *worse* one my sweep structurally could not reach.
D1's prose said "**rewrite** the canonical `## Microworlds` section in place —
same `## ` header, so no new parity-map entry". That section had never existed at
any commit. The criteria were fine; the *narrative* was false, and it drove two
wrong downstream decisions (an affected-file marked conditional that was actually
required, and an acceptance criterion whose stated rationale was the opposite of
what the test proves). Worst part: I already KNEW #130 was unbuilt — I'd noted
"these don't exist yet, that's expected, they're post-conditions" while checking
the very same step's sentinels. The contradiction sat between the prose and the
criteria and I never compared them. Same error then repeated in D9 ("the existing
bundle documentation is updated" — README had zero) and D10 ("those glossary
entries stand" — CONTEXT.md had none).

**How to apply (prose premises):** for every verb in a step that presupposes an
artifact — *rewrite, update, extend, amend, in place, existing, still, preserve,
stands* — run one command proving the artifact exists NOW. `git log -S'<token>'
-- <file>` is the decisive check: empty output means it never existed at any
commit, not merely that it is absent today. Do this especially when the step
inherits language from a plan whose units were never built; a closed-in-favour-of
issue is a *specification*, never an artifact. And when a step edits a file with a
derived-list drift guard (`canonicalHeaders()` in
`tests/adapter-protocol-parity.test.js`), read the guard before asserting whether
a map entry is needed — the guard, not the plan, decides.

**Fourth trap - a criterion can be runnable, correct-shaped, and still evaluated
at the WRONG MOMENT (2026-08-10, microworld dashboard R2/D1/D2/D9).** I wrote
"asserts `git diff --name-only` includes `.claude/persona-config.json`" as the
proof that `bin/cli.js --update` had been run. It can never pass. The reviewer
may only write a PASS marker on a fully-committed tree (`git diff --quiet HEAD`
exits 0), so by the time any criterion is evaluated the bare working-tree diff
is **empty by construction**. Worse, it fails silently - `grep` just finds
nothing - so the reviewer either hand-improvises a substitute or fails the unit
on a technicality. Four occurrences shipped in one "finalized" plan.

This is NOT the vacuous-criterion trap or the prose-premise trap. Each criterion
was individually runnable and individually true-shaped; I authored them against
a mental model of the working tree *mid-implementation* and they were executed
*after the commit that empties it*. Running them at authoring time does not
catch it either, because mid-authoring the tree is often dirty and they appear
to work.

**How to apply (lifecycle):** ask of every criterion "at what moment does the
reviewer run this, and what is true of the tree then?" The tree is COMMITTED and
CLEAN. So: never phrase a criterion against `git diff`, `git diff --name-only`,
or `git diff --stat`. Instead:
- to prove the unit CHANGED X - assert what X now **contains** (sentinel string,
  parsed value, regenerated version stamp);
- to prove the unit did NOT need to change Y - assert Y still contains its
  **expected prior value**, quoted literally with `grep -F`.
Content assertions also beat the range-relative form (`git diff <base>..HEAD`):
a spec is authored before dispatch so no baseline SHA exists to hard-code, and
range-relative breaks on multi-commit units, FAIL->fix cycles, and rebases.
`git status --porcelain` compared before/after a command *within* the review is
fine - that is a delta measured inside the review, not a claim about the commit.

See [[feedback-no-forced-changes]], [[feedback-baselines-expire]], and
[[verify-deferred-issue-premises]].
