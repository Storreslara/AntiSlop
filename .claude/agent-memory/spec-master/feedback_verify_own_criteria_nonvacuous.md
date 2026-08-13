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

**Fifth trap - the criterion's own SHELL QUOTING can make it vacuous
(2026-08-11, gh138 debug spec).** Verifying eight criteria, C4 flipped from RED
to GREEN between two runs of what looked like the same command. Cause: I had
written the pattern in **double quotes**, and this repo's prose is full of
backticked identifiers — so bash read `` `lead-programmer` `` and `` `run.sh` ``
as **command substitution**. Both expanded to empty, the regex silently
collapsed from `` `lead-programmer`[^.;]*executes `run\.sh` `` to
`[^.;]*executes `, and it matched the *unfixed* file. A criterion that passes on
broken input is the exact thing this memory exists to prevent, and here the bug
was in the quoting, not the logic. Always single-quote grep patterns; on a
backtick-heavy repo, double quotes are a live landmine.

**Related shipping trap, same session:** a markdown **table** is the wrong
container for criteria. Table cells need `\|` escaping, and a code span
containing literal backticks terminates early — so the *published* command
stops being the *verified* one. Ship criteria as a fenced `sh` block, then
extract the block back out of the finished document and run it verbatim. That
last step is the only proof that what a dispatched agent will copy is what I
actually tested.

**Sixth trap - a DELETION check can destroy the very rule it claims to protect
(2026-08-13, gh348 finalization).** I shipped `C9.7 ADR-0003's hivemind split is
not violated: spec-master still never runs to-tickets. `grep -c "to-tickets"
agents/spec-master.md` returns 0.` Both halves are individually sensible and the
criterion is runnable — but the file's three occurrences are all *correct*
statements, and one of them IS the prohibition ("You never run `to-tickets` on
any path (ADR-0003 preserved)"). Satisfying it literally deletes the rule it
names. Vacuity is not the only failure mode: a criterion can be aggressively
non-vacuous and still be **backwards**.

**How to apply (deletion vs survival):** when a criterion's prose says a rule
*survives* but its command says a string is *absent*, they are in conflict —
always. Ask which the rule's own text looks like. If the persona corpus states
the rule using the token being greppped, the correct form is a **survival pin**
(`grep -c '<the rule sentence>'` returns 1, RED-provable by mutation: deleting
the rule makes it 0), not a deletion check. Reserve `== 0` for tokens that are
purely the *defect* — an expired date, a superseded phrase, a false claim.

**Seventh trap - `grep -c` on a line-joined file is a BOOLEAN, not a tally
(same session).** The house line-join idiom `tr '\n' ' ' < f | tr -s ' ' | grep
-c 'phrase'` collapses the file to ONE line, so it returns 0 or 1 forever. A
plan recorded baselines of "2" for it; the real joined `grep -c` was 1 and the
*occurrence* count (`grep -o ... | wc -l`) was 2. The criterion still gated
correctly (it demands 0, and stays at 1 until every occurrence is gone — which
is exactly why the join is load-bearing versus a naive line-grep that goes green
after the first fix), but the recorded baseline was unreachable, so anyone
re-deriving it would think the criterion was broken. State which command
produces which number, and use `grep -o | wc -l` whenever the baseline is a
count rather than a presence.

See [[feedback-no-forced-changes]], [[feedback-baselines-expire]],
[[verify-deferred-issue-premises]],
[[docs-units-need-claim-anchored-criteria]], and
[[project-drift-check-idiom-broken]].
