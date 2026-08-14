# Fix: the pending-review-flag-to-unit join mislabels under a broken invariant

**STATUS: FINAL.** Fast path — resolves to 1 dispatchable unit. No tracker
issue filed (routing rule: only ≥3 units get `to-tickets`). Dispatched
directly from this document.

Origin: `gh350`'s reviewer (unit `gh350`, issue #349, already PASSed and
merged at `1c162a58ffa5a0b12033c173d93f2e7c78cf69a9`) found this live and
wrong in this exact repo, recorded as non-blocking note 1 in
`.claude/reviewed/gh350.pass`. This is a follow-up fix to that note, not a
reopening of `gh350`'s verdict — `gh350` matched its acceptance criteria as
written; the criteria themselves had a gap.

## Goal

`bin/microworld-dashboard/decisions.js`'s `joinPendingReviewUnit` (the
function backing touchpoint 4, D-5, of
`docs/plans/2026-08-13-dashboard-decision-approval-surface.md`) must return
`unit: null` for every pending-review entry whenever the one-unit-at-a-time
invariant is broken (more than one `.claude/.review-join.<unit-id>` stamp
standing with no `.claude/reviewed/<unit-id>.pass` written after it) — not
just when zero stamps stand, which is all the shipped code and shipped test
actually cover today. R8 of that document already states this as the
intended mitigation ("emit `unit: null` rather than guess"); this fix makes
that claim true in fact.

## Context

### The bug, verified directly

Read `docs/plans/2026-08-13-dashboard-decision-approval-surface.md`'s R8 and
Step 1 case (d), and `bin/microworld-dashboard/decisions.js` end to end
before writing this spec, per instruction. Confirmed both the code and the
live repo state independently:

- `joinPendingReviewUnit` (`decisions.js:114-145`) scans every
  `.review-join.<unit-id>` stamp, discards ones superseded by a later
  `.pass`, and returns the **newest** of what remains — unconditionally.
  `enumeratePendingReview` (`decisions.js:150,163`) then applies that one
  computed value to **every** pending-review entry.
- With exactly one live stamp (the invariant holding), "newest of one" is
  correct and this is what Step 1 case (d) tests
  (`tests/dashboard-decisions.test.js:145-184`) — both the happy path and
  the zero-stamp `unit: null` path.
- With more than one live stamp (the invariant broken), the same "newest"
  logic still runs and still picks one — silently mislabeling every flag
  that isn't actually about that unit. No test covers this case; it is not
  mentioned by name anywhere in `tests/dashboard-decisions.test.js`.
- This is not hypothetical. Read directly from the live repo on 2026-08-14:
  `.claude/.review-join.gh347-2` and `.claude/.review-join.gh350` both
  stand (neither has a later `.pass` — `gh347-2` is `.escalated`, not
  passed). `.claude/.pending-review.a25a4e49410086331`'s own content reads
  `defer: ... awaiting verdict for gh350`; the sibling flag's content reads
  `defer: ... awaiting verdict for gh347-2`. Both are rendered `unit:
  "gh350"` by the shipped code today, because `gh350`'s stamp
  (`2026-08-14T00:08:45Z`) is newer than `gh347-2`'s
  (`2026-08-14T00:08:35Z`).

### Why null-for-both, not a smarter guess

Neither the `.review-join.<unit-id>` stamp (written by
`reviewer-route-gate.sh`, contains a timestamp and unit-id, no agent-id) nor
the `.pending-review.<agent-id>` flag (contains a timestamp or a free-text
`defer:`/`skip:` reason, no unit-id) carries a field that links a specific
flag to a specific stamp. There is no reliable per-flag disambiguation
available from data already being written today.

**Rejected alternative: parse the free-text `defer:`/`skip:` reason for a
unit id.** Two of the live flags happen to have a human-legible reason
mentioning the right unit, but that reason is composed by whichever agent
(or human) wrote the flag, follows no grammar, and is not guaranteed to
name a unit at all, name the right one, or stay in this shape. Parsing it
would be guessing with extra steps, and would need its own spec (a reason
grammar, a parser, tests for malformed reasons) to do honestly. Out of
scope here.

Given that, `unit: null` for **all** entries during the ambiguous window is
the only honest answer available from data that already exists — the same
answer the zero-stamp case already gives, for the same reason (nothing
reliable to report). This costs nothing new client-side: Step 3 of the
parent spec (the Decisions section UI) has not been built yet — it is not
in `.claude/reviewed/` PASSed or in-flight as far as this repo's `bin/`
tree shows — so there is no existing rendering behavior for `unit: null`
to reconcile; whatever Step 3 does with the zero-stamp case, it does with
the multi-stamp case too, because after this fix they are the same value.

### Scope: what this fix does NOT touch

`gh350`'s reviewer surfaced six other, lower-priority, unrelated findings in
the same file (non-blocking notes 3-8 of `.claude/reviewed/gh350.pass`).
Each touches a different function (`enumerateEscalations`,
`enumerateFindings`, ordering across all four enumerators) with its own
judgment call, not the join logic this fix corrects. Bundling them here
would turn one clean, single-function fix into a multi-purpose diff with
unrelated acceptance criteria, and none of them share this fix's data or
control flow. Recorded as Out of Scope below rather than silently dropped.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Clear
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-08-14 User interaction flow: Q Does `unit: null` in the multi-stamp
  case need its own UI treatment once Step 3 (the Decisions section client)
  ships? → A (self-resolved): no — Step 3 does not exist yet in this repo
  (verified: no client code for a Decisions section, no corresponding
  `.pass` marker), and the parent spec already treats `unit: null` as one
  value with one meaning ("nothing reliable to report"), not two. Whatever
  Step 3 does for the zero-stamp null path it does for this one too; no new
  UI state is introduced by this fix.
- 2026-08-14 Edge cases / failure handling: Q What should
  `joinPendingReviewUnit` return for 0, 1, and >1 live stamps? → A
  (self-resolved): 0 → `null` (unchanged), 1 → that unit id (unchanged), >1
  → `null` (the fix — currently returns the newest instead).
- 2026-08-14 Technical constraints & tradeoffs: Q Can the join disambiguate
  per-flag using existing data? → A (self-resolved): no — see "Why
  null-for-both" above. Not attempted; parsing free text was considered and
  rejected.

### Terminology check (`antislop:ubiquitous-language`, prose mode, against `CONTEXT.md`)

Read `CONTEXT.md`'s **review-join stamp** entry (glossary: "`.claude/.review-join.<unit-id>`,
one per unit currently under review") and the **Review-join stamp condition**
entry before drafting.

- **Lens 1 (glossary term used differently):** none. This document uses
  "review-join stamp", "pending-review flag", and "unit" exactly as
  `CONTEXT.md` defines them; "one per unit currently under review" already
  anticipates more than one existing simultaneously, which is the case this
  fix handles.
- **Lens 2 (new synonym for a defined term):** none found.
- **Lens 3 (load-bearing new term with no entry):** none. This document
  deliberately avoids coining a name for "a review-join stamp not yet
  superseded by a `.pass`" (used as plain description throughout, not a
  defined term) to avoid adding vocabulary for a one-function bug fix.

Advisory only; did not affect dispatch.

## Risks / dependencies

- **No prior `.fail` on this unit.** Surveyed the full `.claude/reviewed/`
  listing (not sampled) on 2026-08-14: no `gh350.fail` exists, and no
  `.fail` exists for any file this fix touches. This is a fresh fix, not a
  retry.
- **Same defect-history family as R3 of the parent spec.** The dashboard
  units `gh315`, `gh317`-`gh320`, `gh323` and the ad hoc restyle fix each
  carried a `.fail` before passing. `gh350` (this file) passed first time,
  but the file itself is young and under active, concurrent change (two
  units were mid-review on it in the same session that produced this bug
  report). Not `haiku` territory.
- **The live repo's two standing flags are a moving target.** By the time
  this fix ships, `gh347-2`'s escalation may already be resolved and its
  stamp/flag gone. The fix must be proven by a fixture-driven test, not by
  re-checking live repo state — the live state is evidence for this spec,
  not part of its acceptance criteria.
- **R8 of the parent spec is now factually wrong until this fix lands and
  is recorded there.** Step 1 of this fix's dispatch unit corrects it in
  place, following the same dated-correction convention that document's own
  R2/D8 vacuity record already established, rather than silently rewriting
  history.

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — the bug, the live repo state, and
  the absence of a Step 3 client were each verified directly (grep, file
  reads, `cat` on the live stamps and flags), not inferred from the
  reviewer's note alone.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied — no
  script-driven artifact (`fileHashes`, mirrors) is touched.
- P3 "Version-stamp discipline": satisfied — does not fire. This fix touches
  `bin/microworld-dashboard/decisions.js`, a test file, and a `docs/plans/`
  correction; none are version-stamped files (`agents/*.md`, templates).
- P5 "`tests/validate.sh` is the merge gate": satisfied — the acceptance
  criteria require it to exit 0.

## Unit count

**1 unit — fast path.** The join fix, its regression test, and the parent
spec's R8 correction are one tightly-coupled change (same bug, same commit,
no independent value in splitting them) touching a fix file, its existing
test file, and one paragraph of an already-published doc. No G1 version-bump
triple fires (no `agents/*.md` involved). Dispatched directly below.

## Unit 1 — `joinPendingReviewUnit`: null on ambiguity, not a guess

**Task-id:** `adhoc-2026-08-14-decision-join-ambiguity-fix`

**Affected files:**
- `bin/microworld-dashboard/decisions.js` (the fix, `joinPendingReviewUnit`,
  currently lines 108-145; also update its leading comment)
- `tests/dashboard-decisions.test.js` (extend Test (d) with the multi-stamp
  case; no new file, no `validate.sh` registration change — it is already
  registered)
- `docs/plans/2026-08-13-dashboard-decision-approval-surface.md` (append a
  dated correction under R8 — do not rewrite the original claim)

**Ordered edits:**
1. In `decisions.js`, rewrite `joinPendingReviewUnit` to collect every stamp
   not superseded by a later `.pass` into a list (instead of tracking a
   single "newest" running value), then return that unit id only when the
   list has **exactly one** entry; return `null` for both zero and more than
   one. Update the function's leading comment (currently describing "the
   newest ... stamp") to state the actual contract: exactly one live stamp
   resolves to that unit, zero or multiple both resolve to `null`, and
   multiple is the invariant-broken case R8 names.
2. In `tests/dashboard-decisions.test.js`, extend Test (d) (or add an
   adjacent case in the same block, clearly labeled) with a fixture
   reproducing the live defect shape: two `.review-join.<unit-id>` stamps
   for two different unit ids, neither superseded by a `.pass`, plus two
   `.pending-review.<agent-id>` flags. Assert both pendingReview entries
   carry `unit: null`. Keep the existing single-stamp and zero-stamp
   assertions in place unchanged (regression).
3. In `docs/plans/2026-08-13-dashboard-decision-approval-surface.md`, under
   R8, append (do not replace) a paragraph beginning `**Correction
   (2026-08-14):**` stating: the original claim was inaccurate — Step 1 case
   (d) as shipped asserted only the zero-stamp null path; the multi-stamp
   (invariant-broken) case instead picked the newest stamp and applied it to
   every pending-review entry, found live in this repo by `gh350`'s reviewer
   (cite `.claude/reviewed/gh350.pass`, non-blocking note 1); fixed by this
   document (name it), which makes the multi-stamp case also return `unit:
   null`.

**Do NOT touch:** `enumeratePendingReview` (its per-entry application of the
joined value is correct and unchanged by this fix — the bug was entirely in
what value it was given), `enumerateEscalations`, `enumerateFindings`,
`enumerateBriefings`, `bin/microworld-dashboard/server.js`,
`bin/microworld-dashboard/index.html`, any `agents/*.md` file, `CONTEXT.md`.

**Acceptance criteria:**
- `node tests/dashboard-decisions.test.js` exits 0, including the new
  multi-stamp case and the pre-existing single-stamp and zero-stamp cases
  in Test (d).
- `bash tests/validate.sh` exits 0 and its output includes an `OK` line for
  `tests/dashboard-decisions.test.js`.
- `grep -n "liveStamps\|length === 1" bin/microworld-dashboard/decisions.js`
  shows the ambiguity check now keys off count, not recency (non-vacuity:
  the prior implementation contains neither string).
- `grep -c 'Correction (2026-08-14)' docs/plans/2026-08-13-dashboard-decision-approval-surface.md`
  is ≥ 1, and `grep -c 'multi-stamp' docs/plans/2026-08-13-dashboard-decision-approval-surface.md`
  is ≥ 1 — both in the paragraph directly following R8 (anchored to the
  claim, not the word, per that document's own established convention).
- `git diff -- docs/plans/2026-08-13-dashboard-decision-approval-surface.md`
  shows only added lines under R8 (a correction paragraph), no removed or
  changed lines — the original claim stays legible as what shipped, per
  that document's own D8/R2 vacuity-record precedent.

**Pre-resolved context:** the live repo state that motivated this fix
(`.claude/.review-join.gh347-2` and `.claude/.review-join.gh350` both
standing, `.claude/.pending-review.a25a4e49410086331` and
`.claude/.pending-review.a2d03ff2de69e4bed` both currently mislabeled
`unit: "gh350"`) is background evidence only, not part of the fixture the
test must use — build the test fixture fresh per this document's Ordered
edit 2, since the live state will not persist.

**Escalation:** if `joinPendingReviewUnit`'s current structure resists this
change without a larger rewrite (e.g., if `enumeratePendingReview`'s
single-computed-value assumption turns out to be load-bearing somewhere not
read during this spec's authoring), stop and report back rather than
expanding scope into `enumeratePendingReview` or the touchpoint-4 design in
`docs/plans/2026-08-13-dashboard-decision-approval-surface.md` — that would
be a different, larger fix needing its own grill.

## Out of Scope

- `decisions.js:122` — the unreachable "/" half of the traversal guard.
  Reviewer's own read: harmless, correctly mirrors
  `reviewer-route-gate.sh:106`. No fix warranted; no gap to ground a diff
  in.
- `decisions.js:28,48` — `enumerateEscalations` has no equivalent traversal
  guard. Real asymmetry, but requires write access to the reviewer-owned
  `.claude/reviewed/`/`.claude/human-review/` directories to exploit, and
  stays inside the project root (`/api/source` already serves that root).
  Different function, different fix, own severity judgment — candidate for
  its own small follow-up, not bundled here.
- `decisions.js:102` — `enumerateFindings`'s slug comes from the file's
  first line, not the containing directory, and the orchestrator deletes by
  directory name (parent spec's D-2). Real correctness gap, but a different
  function with its own design question (which one wins when they
  disagree?) — needs its own small spec, not folded into a join fix.
- `decisions.js:167` — one trailing newline stripped from a "verbatim"
  defer reason. Cosmetic, different function, own tiny fix if ever pursued.
- Stable ordering across all four enumerators (currently readdir order for
  three of the four). Larger blast radius than this fix (touches all four
  functions), and not a correctness bug — determinism/testability
  improvement only.
- "briefing" (`enumerateBriefings`) has zero `CONTEXT.md` hits — a glossary
  gap for `scribe`, not a code defect. Not this persona's fix to make.
- Step 3 (the Decisions section client) — does not exist yet in this repo;
  out of scope by construction, not by choice.

## Self-check

- CHK1: Does the plan state the exact return-value contract for 0, 1, and
  >1 live stamps? — PASS (Clarifications' self-resolved edge-case answer,
  restated in Ordered edit 1).
- CHK2: Does the plan justify why per-flag disambiguation isn't attempted,
  rather than silently choosing the simpler answer? — PASS ("Why
  null-for-both" section, with a named rejected alternative and why it was
  rejected).
- CHK3: Is the acceptance criterion for the code fix verifiable
  independent of the live repo's transient state? — PASS (Risks section
  states the live state is evidence, not fixture; Ordered edit 2 and the
  Pre-resolved context section both require a fresh fixture).
- CHK4: Does the plan avoid silently rewriting the parent spec's now-wrong
  R8 claim? — PASS (Ordered edit 3 and its acceptance criterion require an
  appended, dated correction; a `git diff` criterion enforces added-lines-only).
- CHK5: Are the six other reviewer findings in the same file each given an
  explicit disposition rather than silently dropped? — PASS (Out of Scope
  lists all six by line number with a one-line reason each).
- CHK6: Does `enumeratePendingReview` need to change too, or only
  `joinPendingReviewUnit`? — PASS (Ordered edit's "Do NOT touch" list
  states `enumeratePendingReview`'s per-entry application is already
  correct; the bug was solely in the value it was given).

## Scribe update hint

No `CONTEXT.md`/wiki/ADR update warranted — no new domain term, no new
architecture, and `CONTEXT.md`'s existing **review-join stamp** entry
already anticipates "one per unit currently under review" (i.e., possibly
more than one). This is a same-file bug fix within an already-documented
mechanism, not a new one. If `scribe` disagrees after reading the shipped
diff, that is its call to make, not a gap this spec left open.
