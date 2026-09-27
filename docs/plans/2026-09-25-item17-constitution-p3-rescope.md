# Item 17: Rescope Constitution P3 (version-stamp discipline) to release units

Status: FINAL | Date: 2026-09-25 | Author: spec-master | Item 17 of 19
Source: Fable adversarial review 2026-09-25, reactive-complexity table (Constitution P3)
Disposition: **OPEN QUESTION with a recommendation against the review's framing** — P3 is not merely release hygiene here, but its current scope is genuinely over-broad.

## Goal

Decide whether P3 should remain a per-unit MUST that the reviewer FAILs on, or
be rescoped — and if rescoped, replace the lost coverage mechanically rather
than by dropping it.

## Context

The review's case: *"A version stamp is release hygiene, not a per-unit
correctness property; making it a MUST that the reviewer FAILs on turns every
doc edit into a CHANGELOG edit. Move it to the release unit only."*

`.claude/constitution.md` P3 states: any change to a version-stamped file
(`agents/*.md`, templates) must bump `.claude-plugin/plugin.json`'s version
and add a CHANGELOG entry, **"since the `--update` mechanism depends on the
version actually changing when content does."**

**That closing clause is the part the review's framing omits, and it is
decisive.** P3 is not hygiene for its own sake: `bin/cli.js --update` uses the
version to decide whether a project's adapted files are stale. If content
changes without a version bump, `--update` will not refresh already-adapted
projects, and they silently keep running the old persona prose. That is a
**correctness property of the distribution mechanism**, not a release
convention — and this is a plugin consumed by other repos.

So "move it to the release unit only" would mean: between units, the shipped
version no longer corresponds to the shipped content, and any project running
`--update` mid-stream gets a stale copy with no signal. The review's
reasoning holds for an application; it does not hold for a plugin whose
update path keys on the version.

**But the review's complaint is real at the other end.** Measured from this
project's memory: **two consecutive units (lean-1, lean-2, 2026-09-23) FAILed
solely for a missing version bump**, and a `version-stamp-discipline-gap`
note was written precisely because the rule kept being missed. A MUST that
competent work keeps failing is a badly-placed MUST — the failure mode is
predictable, mechanical, and detectable, which means it should be *caught by
a script*, not adjudicated by an opus reviewer after the fact.

That points to a third option the review did not offer: keep P3's scope,
**mechanize its enforcement**, so it stops consuming reviewer FAIL slots and
the 2-FAIL cap.

## Clarifications

1. Functional scope & success criteria: Clear
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Clear

- 2026-09-25 External dependencies & integrations: Q Is P3 release hygiene or
  a distribution-correctness property? → A (self-resolved): **distribution
  correctness** — `--update` keys on the version to decide staleness, so
  content-without-bump silently strands already-adapted projects. This
  falsifies the review's central premise.
- 2026-09-25 Edge cases / failure handling: Q Does a multi-unit spec need one
  bump per unit or one per spec? → A (self-resolved): **this is the real
  defect.** P3 says "any change… must bump", which read literally demands a
  bump per unit; several units in one spec each touching `agents/*.md` would
  each need one. Nothing states whether per-spec is acceptable. That
  ambiguity is a likely contributor to the lean-1/lean-2 failures.
- 2026-09-25 Technical constraints & tradeoffs: Q Can P3 be mechanized? → A
  (self-resolved): yes in principle — a check comparing "version-stamped file
  changed in this diff" against "version bumped" is expressible. Whether it
  belongs in `validate.sh` or a hook is Step 2's question.

## Risks and dependencies

- **R1. Do not weaken distribution correctness.** Any rescope must preserve
  the property that a shipped version corresponds to shipped content.
- **R2. A blocking mechanical check could be worse than the FAIL.** If the
  check blocks commits, a mid-spec work-in-progress commit becomes
  impossible. Step 2 must decide warn-vs-block deliberately; the safe default
  is to surface it *before* review, not to add a new hard gate.
- **R3. Constitution amendments have their own process.** `.claude/constitution.md`
  carries a version and an amendment log. Any change to P3 must bump the
  constitution's own version and add a log entry — this spec must not edit a
  principle silently.
- **R4.** Two prior FAILs exist on this rule (lean-1, lean-2). Per the
  protocol's durable-warning intent, any unit here should be treated as
  needing more judgment than its size suggests — **do not tag it `haiku`.**

## Constitution check (.claude/constitution.md v1.0.0)

- P1 "Verify, don't assume": satisfied — P3's stated rationale read in full;
  the review's premise checked against it and falsified.
- P2 "Prefer deterministic scripts over LLM re-derivation": **the crux** —
  it directly supports mechanizing P3 rather than leaving it to reviewer
  judgment.
- P3 "Version-stamp discipline": **this spec's subject.** Step 1 edits the
  constitution itself, so the amendment-log obligation in R3 applies.
- P4 "Optional personas degrade gracefully": not engaged.
- P5 "`tests/validate.sh` is the merge gate": engaged by Step 2.

## Step 1 — Clarify P3's unit-vs-spec scope

**Affected files:** `.claude/constitution.md` (principle text + amendment
log + its own version).

Resolve the ambiguity identified in Clarifications: state explicitly whether
the bump is required per **unit** or per **spec/release batch**. Do not
change P3's *coverage* (which files it applies to) in this step.

**Acceptance criteria**
- P3's text states the granularity unambiguously — assert the principle
  contains either "per unit" or "per spec" (or equivalent explicit wording):
  `grep -cE 'per unit|per spec|once per' .claude/constitution.md` ≥ 1.
- The `--update` rationale is preserved:
  `grep -c 'update' .claude/constitution.md` ≥ 1 in P3's text.
- The constitution's own version is bumped and an amendment-log entry added
  naming the change (R3): the version line differs from `HEAD` and the
  amendment log gains a dated line.
- `bash tests/validate.sh` exits 0.

## Step 2 — Mechanize the check — **SUPERSEDED 2026-09-26, NOT DISPATCHABLE**

> Superseded by **Step 3** and **Step 4** below. The detection half specced
> here was already shipped on 2026-09-23 as
> `hooks/scripts/version-stamp-check.sh`, three days before this plan was
> written. See `## Scope reconsideration (2026-09-26)`.

**Affected files:** `tests/validate.sh` or a pre-commit check; tests.

Detect "a version-stamped file changed without a version bump" mechanically,
so it is caught before review rather than by an opus FAIL.

**Acceptance criteria**
- Given a diff touching `agents/*.md` or `templates/*` with no version bump,
  the check reports it, naming the file.
- Given the same diff **with** a bump, it passes.
- Non-vacuity by mutation: stage a version-stamped edit without a bump,
  confirm the check reports; add the bump, confirm it passes. Record both
  observations in the report.
- Warn-vs-block is a **stated, deliberate choice** in the implementation's
  comment, with the reasoning (R2) — not left implicit.
- False-positive check: a diff touching **only** non-version-stamped files
  (e.g. `hooks/scripts/*.sh`, `tests/*`) passes without a bump.
- `bash tests/validate.sh` exits 0.

## Open Questions

1. **Should P3's coverage be narrowed, as the review asks?** Recommended
   default: **no — keep the coverage, mechanize the enforcement** (Steps 1–2).
   The review's premise that this is release hygiene is falsified by P3's own
   `--update` rationale: this is a plugin, and the version is how other
   projects learn their copy is stale. What is genuinely wrong is that a
   predictable, mechanical requirement was being enforced by an expensive
   after-the-fact judgment, which is what cost lean-1 and lean-2. Requires a
   human decision only if the operator wants the coverage narrowed anyway.
2. **Should Step 2's check block or warn?** Recommended default: **warn in
   `validate.sh`, and surface it in the lead-programmer's pre-review
   checklist** — blocking risks making legitimate WIP commits impossible
   (R2), and this repo already has more hard gates than it can comfortably
   reason about. Requires a human decision if a hard gate is preferred.

## Self-check

- CHK1: Is the review's premise checked rather than accepted? — PASS (P3's
  `--update` rationale falsifies "release hygiene").
- CHK2: Is the review's *complaint* addressed even though its premise fails?
  — PASS (two real FAILs; Step 2 mechanizes so the rule stops consuming FAIL
  slots).
- CHK3: Does the spec edit a constitutional principle without process? —
  FAIL (missing) — revised in place: R3 and Step 1's criteria now require the
  constitution's own version bump and an amendment-log entry.
- CHK4: Could Step 2's check fire on files P3 does not cover? — PASS
  (explicit false-positive criterion).
- CHK5: Is the prior FAIL history carried forward per the protocol? — PASS
  (R4 records both FAILs and forbids a `haiku` tag).
- CHK6: Does Step 1 change coverage while claiming only to clarify
  granularity? — PASS (explicitly scoped to granularity; coverage change is
  Open Question 1).

## Scribe update hint

The `version-stamp discipline` glossary entry already exists. Amend it to
record the unit-vs-spec granularity once Step 1 settles it, and to state that
the rule is a distribution-correctness property keyed to `--update` — not
release hygiene. That framing error is what this item began as, and the
glossary should close it.

## Dispatch contract (fast path — 2 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item17-constitution-p3-rescope.md`.
Order: Step 1 → Step 2.

**Model tagging note:** neither unit may be tagged `haiku`. Two prior units
FAILed on this exact rule (R4).

### Unit: item17-1-clarify-p3-granularity
- **Objective:** State whether the bump is per unit or per spec.
- **Retrieval:** Step 1.
- **Affected files:** `.claude/constitution.md`.
- **Ordered edits:** clarify granularity → preserve the `--update` rationale → bump the constitution's own version → add amendment-log entry.
- **Do NOT touch:** P3's coverage (which files it applies to — that is Open Question 1); other principles.
- **Acceptance criteria:** as Step 1.
- **Pre-resolved context:** P3's rationale is distribution correctness (`--update` keys on the version), not release hygiene. The ambiguity — whether a multi-unit spec needs one bump per unit — is unresolved today and likely contributed to two FAILs.
- **Escalation:** if clarifying granularity cannot avoid also changing coverage, report — coverage is reserved for the operator.

### Unit: item17-2-mechanize-p3-check — **SUPERSEDED / NOT DISPATCHABLE (2026-09-26)**

> Do not dispatch. Its deliverable already exists. Replaced by
> `item17-3-wire-p3-check` and `item17-4-name-p3-offenders` in
> `## Dispatch contract (amendment — 2 units)` below.

- **Objective:** Catch a missing bump before review, not by FAIL.
- **Retrieval:** Step 2.
- **Affected files:** `tests/validate.sh` or a pre-commit check; tests.
- **Ordered edits:** implement detection → mutate-prove both directions → false-positive check on non-stamped files → state warn-vs-block choice in a comment.
- **Do NOT touch:** the constitution (item17-1 owns it).
- **Acceptance criteria:** as Step 2.
- **Pre-resolved context:** depends on item17-1's granularity decision. Version-stamped files are `agents/*.md` and templates. Two units (lean-1, lean-2, 2026-09-23) FAILed for a missing bump — this check exists to make that class impossible.
- **Escalation:** if a warn-only check cannot be expressed without affecting `validate.sh`'s exit code, report rather than silently making it blocking.

---

## Scope reconsideration (2026-09-26)

**Decision: Step 2's *detection* half is already shipped and is not
re-buildable work; Step 2's *goal* is nonetheless unmet.** `item17-2` is
withdrawn. Two narrow replacement units ship instead: **Step 3** wires the
existing check into the two personas that author commits touching
version-stamped paths (the load-bearing gap), and **Step 4** closes the one
Step 2 criterion the shipped script genuinely does not meet (`violation` does
not name what violated). Neither unit writes a new detector.

Trigger: during item17-1's review the reviewer flagged, unprompted, that
`hooks/scripts/version-stamp-check.sh` and
`tests/version-stamp-check.test.sh` shipped **2026-09-23**
(`CHANGELOG.md:198-202`, version 0.31.76, units `version-stamp-guard-1` and
`version-stamp-check-roast-1`) — **three days before this plan was authored on
2026-09-25**. Step 2 was written without knowledge of them.

### Criterion-by-criterion audit of Step 2 against the shipped tooling

Every Step 2 criterion, checked against the script and its suite as they stand
at `b910b90`:

| Step 2 criterion | Status | Evidence |
|---|---|---|
| Diff touching `agents/*.md` or `templates/*` with no bump → the check reports it | **satisfied** | `version-stamp-check.sh:105-110`; suite cases `agents-touched-no-bump`, `templates-touched-no-bump` |
| …**naming the file** | **NOT satisfied** | Output is a fixed five-field line with no path or sha field (`:106`, `:110`). This is Step 4. |
| Same diff **with** a bump → passes | **satisfied** | suite cases `agents-touched-with-bump`, `templates-touched-with-bump` |
| Non-vacuity by mutation, both directions | **satisfied, and exceeded** | five mutation controls: `mc1` (drop the `agents/*.md` glob → violation flips to `ok`), `mc2` (invert the version comparison → `ok` flips to `violation`), `mc3` (disable the `python3` guard → proves it load-bearing), `mc4` (disable the per-commit loop → widened range flips to `ok`), `mc5` (disable the unmeasurable guard). `mutate()` (`tests/version-stamp-check.test.sh:126-137`) fails loudly if a `sed` matched nothing, so a silently-unmutated copy cannot "prove" anything. |
| Warn-vs-block is a stated deliberate choice, with reasoning | **satisfied in substance** | `version-stamp-check.sh:19-28` states the posture (`exit 0 always`) and its reasoning explicitly, under a `NOT A HOOK` heading. The reasoning given is *reviewer-invoked / CI shallow clone*, not R2's *WIP-commit* argument — a different route to the same posture, not an absent one. |
| False-positive check on non-version-stamped files | **satisfied** | suite cases `unrelated-file` (`README.md`) and `hooks-scripts-only-not-gated` (`hooks/scripts/*.sh`) |
| `bash tests/validate.sh` exits 0 | **satisfied** | suite registered at `tests/validate.sh:681-685`; re-run standalone here → **rc=0**, 14 behavioural cases + 5 mutation controls all `OK` |

Six of seven criteria are met; the seventh is Step 4. Additionally the script
already implements the granularity item17-1 landed today — per-commit,
each commit checked against its own immediate parent (`:79-103`) — so the
mechanization and the constitution now agree without further work. Confirmed
live on real history: `bash hooks/scripts/version-stamp-check.sh
61ff35a~1..e9f07c2` → `version-stamp-check: violation touched: yes old:
0.31.60 new: 0.31.61`.

### Why Step 2's *goal* is nevertheless unmet

Step 2's goal was "caught **before review** rather than by an opus FAIL." The
detector exists; nothing causes it to run.

1. **No persona is told to invoke it.** `grep -c 'version-stamp'` returns **0**
   for `agents/reviewer.md`, `agents/lead-programmer.md`,
   `templates/persona-protocol.md`, and both `.claude/agents/` mirrors. The
   string appears only in `.claude/constitution.md`, `docs/trust-model.md`
   (row 25), `docs/harness-glossary.md`, `CONTEXT.md`, two agent-memory notes,
   and `persona-config.json`'s `fileHashes`. The script's own header calls it
   "REVIEWER-INVOKED", and `docs/trust-model.md:63` classifies it
   `self-reported` with the caveat that "nothing independently re-derives
   whether the reviewer actually ran it against the right range" — but no
   reviewer instruction anywhere asks for it. The invocation is documented as
   a property of the script, never as a duty of an agent.
2. **`tests/validate.sh` registers the *test suite*, not the check.** The
   merge gate proves the detector works on a throwaway fixture repo; it never
   runs the detector against this repo's own history. Passing `validate.sh`
   therefore carries no evidence about P3 compliance.
3. **A real violation slipped through after the script shipped.** Sweeping
   every commit from 2026-09-23 to 2026-09-26 that touches a version-stamped
   path (19 commits), three report `violation`: `88d2fc4` and `ae00d99`
   (2026-09-25) and `a9c1040` (2026-09-26). All three confirmed by reading
   `.claude-plugin/plugin.json`'s `version` at each commit and its parent —
   unchanged in every case (`0.31.85`, `0.31.86`, `0.31.88` respectively).
   Of the three, **`a9c1040` is a genuine distribution-correctness
   violation**: it edited `templates/persona-protocol.md`, the shipped
   protocol template, under an unchanged version. See the premise correction
   below for why the other two are not.

So the honest reading is not "Step 2 is done" and not "Step 2 is undone" — it
is **"the detector was built and the loop was never closed."**

### Premise corrections to the inputs

1. **"May already be substantially achieved" understates it — the detection
   half is achieved, and exceeds what Step 2 asked for.** Step 2 asked for
   mutation proof "both directions"; the shipped suite carries five mutation
   controls plus a guard that fails loudly on an unmutated copy. Step 2's
   false-positive criterion named `hooks/scripts/*.sh` and `tests/*` as
   examples; the suite tests exactly `hooks/scripts/*.sh`.
2. **The CHANGELOG-entry half is a real coverage gap, but it is not Step 2's
   gap and it would add no detection power here.** `CONTEXT.md:147-148` is
   verbatim correct: "Mechanization covers the version-bump half of the
   discipline only; the CHANGELOG-entry half remains reviewer-inspection-only."
   But Step 2's own criteria never mention CHANGELOG — all six are about the
   version bump. And measured: of **37** commits since 2026-09-01 touching a
   version-stamped path, **9** lacked a same-commit CHANGELOG entry, and **all
   9 are already reported `violation` by the existing bump check**. Across that
   window CHANGELOG co-presence and version-bump co-presence are perfectly
   correlated, so adding a CHANGELOG check would have caught **zero**
   additional commits. It is therefore explicitly deferred (see Open Question
   4), not silently dropped.
3. **Two of the three post-ship violations are P3 coverage over-breadth, not
   distribution failures.** `88d2fc4` and `ae00d99` touch **only**
   `templates/persona-config.schema.json`. That file is **never shipped to a
   consumer project**: `bin/cli.js` names it only inside comments (`:281`,
   `:333`), it is absent from `.claude/`, and it has no `fileHashes` entry. It
   therefore produces no ADAPT-copied artifact, carries no
   `<!-- antislop vX.Y.Z ... -->` stamp, and cannot go stale — so a bump for it
   delivers nothing. `templates/settings-fragment.json` is in the same
   position for a different reason (`--update` returns before the
   settings-fragment merge is reached). Two of the six files under
   `templates/` are thus outside the `--update` staleness path entirely, while
   P3's literal wording and the script's `templates/*` glob cover all six.
   The script is faithful to the ratified rule; **the rule is over-broad.**
   This is Open Question 1's territory (coverage is reserved for the
   operator), so it is raised as Open Question 3 below rather than specced.
4. **The glossary already encodes the distinction that makes item 3 precise.**
   `CONTEXT.md:63-71` separates **version-stamped file** ("any ADAPT-copied
   file carrying a `<!-- antislop vX.Y.Z ... -->` comment") from
   **version-stamped path** (the canonical sources `agents/*.md`,
   `templates/`), and directs readers to prefer the former. P3 and the script
   both operate in the *path* sense. `templates/persona-config.schema.json` is
   a version-stamped **path** that produces no version-stamped **file** — the
   over-breadth is visible in the vocabulary before it is visible in the code.
5. **A git `pre-commit` hook is not an available route.** `.git/hooks/pre-commit`
   exists but is untracked, 5 lines, and installed by `code-review-graph`
   ("Remove this file to disable pre-commit graph checks"). The repo ships no
   tracked git-hook installer — `scripts/` contains none. Anything added there
   would be per-clone, unversioned, and an edit to a third-party-managed file.
   Rejected on evidence, not preference.
6. **Registering the check as a Claude Code hook is a larger change than it
   looks, and reverses a reviewed decision.** `hooks/hooks.json` has **no
   `PostToolUse` matcher for `Bash`** (only `Edit|Write`), so this would add a
   new hook on the hottest tool path, needing a wrapper that parses the Bash
   payload to decide a commit even happened, plus a trust-model row, a
   bijection-count bump, a hook test, and mirror regeneration — and it would
   contradict `version-stamp-check.sh:19-28`'s ratified "DELIBERATELY NOT
   registered" decision and `docs/trust-model.md:63`'s `self-reported`
   classification. That is a spec, not a narrow unit. Deferred as Open
   Question 2 with a re-open trigger.

### Clarifications (amendment round, 2026-09-26)

1. Functional scope & success criteria: Partial
2. Domain entities / data model: Clear
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Clear
9. Completion / acceptance signals: Partial

- 2026-09-26 Functional scope & success criteria: Q Is Step 2 redundant
  wholesale, or only partly? → A (self-resolved): **partly** — six of seven
  criteria are met by shipped tooling, the seventh ("naming the file") is not,
  and the *goal* is unmet for a reason none of the criteria measured (nothing
  invokes the detector). Recording "satisfied" would have shipped a false
  statement; recording "still needed" would have re-built a working script.
- 2026-09-26 Non-functional attributes: Q Does closing the loop mechanically
  cost anything on the hot path? → A (self-resolved): yes — the only
  mechanical route is a new `PostToolUse` hook on `Bash`, a matcher that does
  not exist today and that would fire on every Bash call in every session.
  Against a measured rate of one genuine violation in three days, that cost is
  not yet earned; Open Question 2 records the threshold at which it is.
- 2026-09-26 External dependencies & integrations: Q Is every file under
  `templates/` actually on the `--update` staleness path? → A (self-resolved):
  **no — two of six are not.** `persona-config.schema.json` is comment-only in
  `bin/cli.js` and never copied; `settings-fragment.json` is never reached by
  `--update`. Neither can go stale, so neither can justify a bump.
- 2026-09-26 Edge cases / failure handling: Q What breaks if the script's
  output line gains a field? → A (self-resolved): the suite's `run_case`
  regex is `$`-anchored at `new: \S+` (`tests/version-stamp-check.test.sh:41`),
  so **all 14 behavioural cases fail at once** unless the regex is widened in
  the same edit. Step 4's ordered edits put the regex first for exactly this
  reason.
- 2026-09-26 Technical constraints & tradeoffs: Q Prose instruction, or a
  mechanical gate? → A (self-resolved): **prose, this round.** Prose is the
  weaker instrument and this plan's own Context says a MUST that competent work
  keeps failing is badly placed — but the failures on record are failures of
  a *rule with no runnable check named anywhere*, not failures of a named
  command. No agent has yet been told "run this script"; that instruction is
  untested here, not known-failed. Open Question 2 fixes the escalation
  trigger so this is a first attempt with a deadline, not an indefinite bet.
- 2026-09-26 Completion / acceptance signals: Q What proves the wiring works,
  rather than merely exists? → A (self-resolved): Step 3's own commit is the
  proof carrier. It edits `agents/*.md`, so P3 binds it, so
  `version-stamp-check.sh` run over that very commit must report
  `ok touched: yes` — the unit is required to pass the check it installs. Paired
  with a parent-commit absence assertion, that is non-vacuous in both
  directions.

### Constitution check (.claude/constitution.md v1.1.0)

- P1 "Verify, don't assume": satisfied — every inherited claim re-measured.
  The reviewer's "may already be achieved" was checked criterion-by-criterion;
  `CONTEXT.md:147-148` was read rather than trusted; the three post-ship
  violations were confirmed against `plugin.json` at each commit and parent;
  the existing suite was re-run standalone (rc=0) rather than assumed green.
- P2 "Prefer deterministic scripts over LLM re-derivation": **deviation —
  justified.** The deterministic route (a `PostToolUse` hook) is named,
  costed, and deferred to Open Question 2 rather than adopted, because it
  reverses a reviewed "NOT A HOOK" decision and adds a hook to the hottest
  tool path for a measured one-violation-in-three-days rate. Step 3 instead
  names an existing deterministic script inside a persona instruction — a
  narrower deviation than leaving the rule to reviewer judgment, which is the
  status quo this item exists to end.
- P3 "Version-stamp discipline": engaged, and self-applied. Step 3 edits
  `agents/*.md` and therefore owes a same-commit bump plus CHANGELOG entry;
  both are acceptance criteria, and the unit must satisfy its own check.
  Step 4 touches only `hooks/scripts/` and `tests/`, so it owes no bump —
  precedent stated in `CHANGELOG.md`'s own 0.31.76 entry.
- P4 "Optional personas degrade gracefully": engaged — `scribe` is an optional
  persona, so Step 3's `agents/scribe.md` edit must not make
  `agents/lead-programmer.md`'s instruction depend on scribe existing. The two
  edits are independent by construction.
- P5 "`tests/validate.sh` is the merge gate": engaged by both units;
  `validate.sh` asserts `agents/*.md` ↔ `.claude/agents/*.md` mirror parity, so
  Step 3 cannot skip `node bin/cli.js --update`.

## Step 3 — Wire the shipped check into the personas that commit version-stamped changes

**Affected files:** `agents/lead-programmer.md`, `agents/scribe.md`;
`.claude/agents/lead-programmer.md`, `.claude/agents/scribe.md` and
`.claude/persona-config.json` (regenerated — see below, never hand-edited);
`.claude-plugin/plugin.json` and `package.json` (version bump);
`CHANGELOG.md`. All in **one commit**, per P3 as clarified by item17-1.

Teach the two personas that author commits touching version-stamped paths to
run the existing check themselves before handing work on, so a missing bump is
fixed by the author in the same commit instead of costing a reviewer FAIL
round. Do **not** write a new detector, do not register a hook, and do not add
the check to `agents/reviewer.md` — a reviewer-side check produces exactly the
FAIL this item exists to prevent (see Open Question 2).

Coverage rationale, stated because git cannot support it: all commits in this
repo carry one author, so the three post-ship violations cannot be attributed
to a persona from history. Coverage is therefore chosen by **capability** —
`lead-programmer` and `scribe` are the personas whose dispatches edit
`agents/*.md` and `templates/`; `spec-master` writes `docs/plans/`,
`reviewer` writes markers, and the rest do not touch version-stamped paths.

**Acceptance criteria**
- Both personas name the script: `grep -c 'version-stamp-check.sh'
  agents/lead-programmer.md` ≥ 1 **and** `grep -c 'version-stamp-check.sh'
  agents/scribe.md` ≥ 1.
- The instruction is runnable, not a restatement of the rule — it shows a
  commit-range argument: `grep -cE 'version-stamp-check\.sh [^ ]*\.\.'
  agents/lead-programmer.md` ≥ 1 and likewise for `agents/scribe.md`.
- Non-vacuity, absence direction: `git show HEAD~1:agents/lead-programmer.md |
  grep -c 'version-stamp-check' || true` → `0`, and likewise for
  `agents/scribe.md`. (This is the measured pre-state; it must still hold at
  the unit's parent. The `|| true` is load-bearing: `grep -c` prints `0` **and
  exits 1** on zero matches, so the bare form looks like a failed command under
  `set -e` — verified both ways while authoring these criteria.)
- **Self-application.** The unit's own commit edits `agents/*.md`, so:
  `bash hooks/scripts/version-stamp-check.sh HEAD~1..HEAD` prints
  `version-stamp-check: ok touched: yes old: <X> new: <Y>` with `X != Y`.
  A `violation` here means the unit failed the rule it just installed.
- Same-commit CHANGELOG entry: `git diff --no-renames --name-only HEAD~1 HEAD
  -- | grep -qx 'CHANGELOG.md'`.
- Mirrors and `fileHashes` regenerated via `node bin/cli.js --update` (never
  hand-edited — `.claude/persona-config.json` is Set A to
  `harness-integrity-gate.sh`, which blocks direct writes and names
  `node bin/cli.js --update` as the only route).
- `bash tests/validate.sh` exits 0 — run it in the **foreground** with a
  raised `timeout` (it took 5m38s in item17-1, inside the 600000 ms ceiling).

## Step 4 — Make `violation` name the offending commit(s) and path(s)

**Affected files:** `hooks/scripts/version-stamp-check.sh`,
`tests/version-stamp-check.test.sh`; `.claude/hooks/scripts/version-stamp-check.sh`
and `.claude/persona-config.json` (regenerated via `node bin/cli.js --update`);
`CHANGELOG.md`. **No version bump** — neither `hooks/scripts/` nor `tests/` is
a version-stamped path, per the precedent stated in `CHANGELOG.md`'s 0.31.76
entry.

Closes Step 2's one unmet criterion. Today a `violation` over a multi-commit
range says only `touched: yes`; identifying *which* commit and *which* file
requires hand-writing a `rev-list` loop — done twice while preparing this
amendment, and the reason the three post-ship violations were not visible to
anyone who merely ran the script over a unit range.

Extend the output line with a **trailing** field naming the offenders, so the
existing five fields keep their positions:

```
version-stamp-check: violation touched: yes old: 0.31.60 new: 0.31.61 offenders: 61ff35a:agents/spec-master.md
```

`offenders:` is `-` for every non-`violation` verdict. Multiple offenders are
comma-separated; a commit's paths are the version-stamped paths it touched.

**Acceptance criteria**
- Real history, content direction: `bash hooks/scripts/version-stamp-check.sh
  61ff35a~1..e9f07c2` still reports `violation` **and** its output names both
  `61ff35a` and an `agents/` path — `61ff35a` touches `agents/spec-master.md`
  and `agents/milestone-auditor.md`, verified.
- Format stability: for an `ok` verdict and for an `unknown` verdict the field
  is present and reads `offenders: -`.
- **All 14 pre-existing behavioural cases still pass.** The suite's `run_case`
  regex (`tests/version-stamp-check.test.sh:41`) is `$`-anchored at
  `new: \S+`; widen it to admit the trailing field **first**, before touching
  the script, or every case fails at once.
- **All 5 pre-existing mutation controls still fire**, `mc1` in particular:
  its `sed` (`s#agents/\*\.md|templates/\*#templates/\*#`) rewrites the glob on
  every line that carries it, and `mutate()` aborts loudly if it matches
  nothing. If offender collection introduces the glob in a form that `sed`
  cannot reach, `mc1` silently stops discriminating — re-read its output, do
  not just read the suite's exit code.
- **New mutation control**: stub or disable the offender-collection step and
  confirm the real-history case above stops naming `61ff35a`, proving the
  field is computed rather than hardcoded.
- `bash tests/validate.sh` exits 0 (foreground, raised `timeout`).

## Dispatch contract (amendment — 2 units)

Retrieval contract: this document,
`/home/sebas/AntiSlop/docs/plans/2026-09-25-item17-constitution-p3-rescope.md`
— read `## Scope reconsideration (2026-09-26)` and your own Step. No tracker
issue exists for either unit (fast path); no issue-closing duty applies.

Order: **independent.** Step 4 does not depend on Step 3, and Step 3 does not
depend on Step 4. If both are dispatched, land Step 3 first so its
self-application criterion is asserted against today's output format rather
than a format changed mid-flight.

**Model tagging note:** neither unit may be tagged `haiku`. Three prior FAILs
now attach to this rule — `reviewer-changes-examples-lean-1`,
`reviewer-changes-examples-lean-2` (both 2026-09-23, missing version bump) and
`item17-1-clarify-p3-granularity` (`.fail` record stamped
`2026-09-27T02:16:37Z`, i.e. late on 2026-09-26 local; four defects, every
machine-check green while the *value* chosen was wrong). That last one is the
warning that matters here: on this rule, green criteria have already
co-existed with a wrong answer once.

### Unit: item17-3-wire-p3-check
- **Objective:** Make the shipped P3 check actually run before review, by
  naming it as a duty in the two personas that commit version-stamped changes.
- **Retrieval:** Step 3 of this document, plus `## Scope reconsideration
  (2026-09-26)` for why no new detector is wanted.
- **Affected files:** `agents/lead-programmer.md`, `agents/scribe.md`
  (sources); `.claude/agents/lead-programmer.md`,
  `.claude/agents/scribe.md`, `.claude/persona-config.json` (regenerated by
  `node bin/cli.js --update` — commit whatever it writes);
  `.claude-plugin/plugin.json`, `package.json` (bump); `CHANGELOG.md`.
- **Ordered edits:** add the instruction to `agents/lead-programmer.md`,
  attached to its existing "Don't grade your own work" / ready-for-review
  bullet (`agents/lead-programmer.md:58-72`) → add the equivalent to
  `agents/scribe.md`, phrased so it does not depend on `lead-programmer`
  running first → bump `.claude-plugin/plugin.json` and `package.json` →
  write the `CHANGELOG.md` entry → `node bin/cli.js --update` → stage
  everything and commit **once** → verify the self-application criterion
  against that commit.
- **Do NOT touch:** `agents/reviewer.md` or `templates/persona-protocol.md`
  (a reviewer-side check re-creates the FAIL cost this item exists to remove,
  and the shared protocol block is trimmed per-persona, so a protocol edit
  does not reliably reach both targets); `.claude/constitution.md` (item17-1
  owns it, and it is now at v1.1.0); P3's coverage (Open Question 1, then 3);
  `hooks/scripts/version-stamp-check.sh` (item17-4 owns it);
  `hooks/hooks.json` (Open Question 2, and it is Set B to
  `harness-integrity-gate.sh`).
- **Acceptance criteria:** as Step 3.
- **Pre-resolved context:** The detector exists and is green — do not write
  one. `grep -c 'version-stamp'` is **0** across
  `agents/lead-programmer.md`, `agents/scribe.md`, `agents/reviewer.md` and
  `templates/persona-protocol.md`, so this is a first occurrence, not a
  repair. The correct invocation is
  `bash hooks/scripts/version-stamp-check.sh <baseline>..HEAD` from the repo
  root; `lead-programmer`'s advisory review packet already carries a
  `baseline..HEAD` range, so the instruction can reuse that range rather than
  defining a new one. Verdicts are `ok` / `violation` / `unknown`; `unknown`
  means an [[unmeasurable range]] and must not be read as `ok`. Vocabulary:
  use **version-stamped file** / **version-stamp discipline**, both defined in
  `CONTEXT.md` (`:63-71`, `:128-148`); do not coin a synonym.
- **Escalation:** if the instruction cannot be added to `agents/scribe.md`
  without making it conditional on the `lead-programmer` persona existing
  (constitution P4), report rather than coupling them. If `node bin/cli.js
  --update` regenerates files beyond the mirrors and `fileHashes` listed
  above, report the extra surfaces before committing rather than absorbing
  them silently.

### Unit: item17-4-name-p3-offenders
- **Objective:** Make a `violation` verdict name the commit(s) and path(s)
  that caused it, closing Step 2's only unmet criterion.
- **Retrieval:** Step 4 of this document.
- **Affected files:** `hooks/scripts/version-stamp-check.sh`,
  `tests/version-stamp-check.test.sh`;
  `.claude/hooks/scripts/version-stamp-check.sh`,
  `.claude/persona-config.json` (regenerated by `node bin/cli.js --update`);
  `CHANGELOG.md`.
- **Ordered edits:** widen `run_case`'s regex
  (`tests/version-stamp-check.test.sh:41`) to admit a trailing `offenders:`
  field and confirm all 14 existing cases still pass **before** changing the
  script → collect offending `<short-sha>:<path>` pairs inside the existing
  per-commit loop (`hooks/scripts/version-stamp-check.sh:84-103`) → emit the
  trailing field on all four output paths, `-` for every non-`violation`
  verdict → add the new mutation control → re-run the suite and re-read
  `mc1`–`mc5`'s output lines individually → `node bin/cli.js --update` →
  `CHANGELOG.md` entry → commit.
- **Do NOT touch:** the five existing output fields or their order (consumers
  and every suite case are positional); the `ok` / `violation` / `unknown`
  verdict vocabulary; the per-commit semantics themselves; the deliberate
  `exit 0` fail-open posture and the `NOT A HOOK` header block (`:19-28`);
  `hooks/hooks.json`; `agents/*.md` (item17-3 owns those, and touching one
  would drag a version bump into this unit).
- **Acceptance criteria:** as Step 4.
- **Pre-resolved context:** No version bump is owed — `hooks/scripts/` and
  `tests/` are not version-stamped paths, and `CHANGELOG.md`'s 0.31.76 entry
  states that precedent explicitly for this very script. The suite builds a
  throwaway git repo (`tests/version-stamp-check.test.sh:11-34`), so new cases
  follow `snap()`/`run_case()` rather than touching real history; the one
  real-history assertion (`61ff35a~1..e9f07c2`) is a live-repo check and is
  deliberately paired with fixture-repo cases, which are the durable ones.
  `mutate()` already fails loudly on a `sed` that matches nothing — keep that
  guard for the new control. `docs/trust-model.md:63` describes this script's
  output contract; if the row's wording becomes inaccurate, say so rather than
  editing it (a trust-model row change pulls in
  `tests/trust-model-bijection.test.js`'s counts).
- **Escalation:** if the trailing field cannot be added without changing one
  of the five existing fields or the verdict vocabulary, stop and report — a
  positional break would silently invalidate all 14 suite cases and any
  reviewer prose that reads the line. If `mc1` stops discriminating after the
  change, report that rather than rewriting `mc1` to fit the new code.

## Open Questions (amendment round)

1. *(carried forward, unchanged)* Should P3's coverage be narrowed, as the
   original review asks? Recommended default: **no** — see the original Open
   Question 1. Open Question 3 below refines what "narrowed" would now mean.
2. **Should the check become a mechanical gate rather than a persona
   instruction?** Recommended default: **not yet — revisit on the first
   post-Step-3 violation.** The mechanical route is a new `PostToolUse` hook
   matching `Bash`, a matcher `hooks/hooks.json` does not currently have; it
   would fire on every Bash call in every session, need a wrapper that
   determines from the payload whether a commit actually happened, and
   contradict `version-stamp-check.sh:19-28`'s reviewed "DELIBERATELY NOT
   registered" decision plus `docs/trust-model.md:63`'s `self-reported`
   classification (which `tests/trust-model-bijection.test.js` pins by count).
   Measured rate is one genuine violation in the three days since the script
   shipped. **Re-open trigger, stated so it is not a matter of taste:** if
   `bash hooks/scripts/version-stamp-check.sh <range>` reports a `violation`
   on any commit landed *after* item17-3, escalate to the hook design and
   treat the prose instruction as falsified. Requires a human decision if the
   operator wants the hook now regardless of the rate.
3. **Should P3's coverage be narrowed to paths that can actually go stale?**
   Recommended default: **yes, and it is a smaller change than "narrow the
   coverage" sounded in Open Question 1.** Measured: two of the six files
   under `templates/` cannot strand a consumer —
   `templates/persona-config.schema.json` is never copied out of the repo
   (`bin/cli.js` names it only in comments at `:281`, `:333`; absent from
   `.claude/` and from `fileHashes`), and `templates/settings-fragment.json`
   is never reached by `--update`. Two of the three post-ship `violation`
   reports were the schema file alone. Narrowing P3 and the script's glob to
   the four shipped files would remove that false-positive class without
   weakening distribution correctness at all (R1 preserved by construction).
   **Requires a human decision** — coverage is reserved for the operator, and
   this would amend `.claude/constitution.md` again (v1.1.0 → v1.2.0) plus the
   script, its suite, `CONTEXT.md:128-148` and `docs/harness-glossary.md`.
   Not specced here.
4. **Should the CHANGELOG-entry half be mechanized?** Recommended default:
   **no, on measured grounds.** All 9 same-commit-CHANGELOG-missing commits in
   the last month are already reported `violation` by the bump check; the
   marginal detection is **zero** across 37 commits. A co-presence test is
   also a weak proxy — touching `CHANGELOG.md` is not the same as adding an
   entry *for this change* — so it would buy a false sense of coverage.
   `CONTEXT.md:147-148` already records the gap honestly; leave it recorded.
   Requires a human decision only if the operator wants the half closed for
   completeness rather than for detection.

## Self-check (amendment round)

- CHK-A1: Does the amendment state, per criterion, which of Step 2's
  acceptance criteria are met and which are not? — PASS (seven-row audit
  table; six met, one not, each with file:line or suite-case evidence).
- CHK-A2: Is the claim "the detector already exists" verified rather than
  inherited from the reviewer's flag? — PASS (script and suite read in full,
  suite re-run standalone to rc=0, live run on `61ff35a~1..e9f07c2`).
- CHK-A3: Is the claim "nothing invokes it" measured, or assumed from the
  absence of prose? — PASS (`grep -c 'version-stamp'` → 0 across four persona
  surfaces, with the non-zero surfaces enumerated so the zero is not a
  search-scope artifact).
- CHK-A4: Does the amendment distinguish genuine distribution-correctness
  violations from P3 coverage over-breadth? — FAIL (missing on first draft:
  all three post-ship violations were initially presented as equivalent) —
  revised in place: premise correction 3 now shows two of the three touch only
  a never-shipped file, and the count of genuine violations is stated as one.
- CHK-A5: Is "prose instead of a gate" defended, given this plan's own Context
  argues a repeatedly-missed MUST should be caught by a script? — FAIL
  (conflicting on first draft: the Context section and the amendment's
  recommendation disagreed) — revised in place: the Clarifications entry
  distinguishes a rule with no runnable check named anywhere (what actually
  failed) from a named command (untested here), and Open Question 2 fixes a
  falsification trigger so the bet has a deadline.
- CHK-A6: Does Step 3 have a criterion that fails if the instruction is added
  but wrong, rather than only if it is absent? — PASS (self-application: the
  unit's own commit must be reported `ok touched: yes` by the very check it
  wires, plus a parent-commit absence assertion for the other direction).
- CHK-A7: Does Step 4 account for the blast radius of changing a
  regex-pinned output format? — PASS (the `$`-anchored `run_case` regex is
  named at file:line, widening it is ordered first, and `mc1`'s silent-
  degradation mode is called out with the instruction to re-read its output
  rather than the suite's exit code).
- CHK-A8: Is the CHANGELOG-entry half disposed of rather than quietly
  dropped from Step 2's scope? — PASS (premise correction 2 plus Open
  Question 4, with the measured zero-marginal-detection figure).
- CHK-A9: Do Steps 3 and 4 agree about which files each owns, so neither can
  drag the other's version-bump obligation into its commit? — PASS (Step 3
  owns `agents/*.md` and owes a bump; Step 4 owns `hooks/scripts/` and `tests/`
  and owes none; each unit's "Do NOT touch" names the other's files).
- CHK-A10: Does any Open Question lack a recommended default, or any FAIL lack
  a resolution? — PASS (all four Open Questions carry a default and state
  whether a human decision is required; both FAILs were revised in place, so
  no FAIL needed converting).

## Risks added by the amendment

- **R5. Step 3 ships a persona instruction, which is compliance, not
  enforcement.** An agent can still skip it. Accepted deliberately, with
  Open Question 2's re-open trigger as the falsification condition. Do not
  let a PASS on item17-3 be read as "P3 is now mechanized" — it is not;
  `docs/trust-model.md:63` stays `self-reported` and stays accurate.
- **R6. Step 4 changes an output format that a `$`-anchored regex pins in 14
  places.** A partial edit fails the whole suite at once. Ordered edits put
  the regex first; the trailing-field design keeps the five existing fields
  positionally stable.
- **R7. `mc1` can stop discriminating without failing.** `mutate()` guards
  against a no-match `sed`, but not against a mutation that no longer changes
  behaviour. Step 4's criteria require re-reading `mc1`–`mc5`'s individual
  output lines, not just the suite's exit code.
- **R8. item17-1's per-commit clarification retroactively reclassifies
  history.** `1a20c7d` and `c6c2476` (lean-1 / lean-2) deliberately closed P3
  in a *third* commit, which `CHANGELOG.md`'s 0.31.74 entry records as
  intentional for the pair; under v1.1.0's per-commit rule both now report
  `violation`. Four older commits (`3a66c71`, `1e066da`, `780ca6a`, `ceaadd7`)
  do likewise. This is expected, is not work for these units, and must not be
  "fixed" by rewriting history — but anyone running the check over an old
  range should know the reports are correct and the commits are closed.

## Scribe update hint (amendment round)

Two amendments, once item17-3 and item17-4 land. (1) `CONTEXT.md`'s
**version-stamp discipline** entry (`:128-148`) should record that the
mechanization is *reviewer- and author-invoked prose*, not a gate, and name
which personas are instructed to run it — the entry currently describes the
script's existence without saying who runs it, which is the exact gap this
amendment found. (2) If Open Question 3 is ever taken up, the
**Version-stamped file** / **version-stamped path** split (`:63-71`) is where
the fix belongs: the two `templates/` files that produce no ADAPT-copied
artifact are version-stamped *paths* that are not version-stamped *files*, and
saying so in the glossary would have made the over-breadth visible without a
measurement. (3) Step 4 introduces one load-bearing new term — the
**offending commit** / `offenders:` output field, the commits and paths a
`violation` verdict is attributed to. That is script-output vocabulary, so it
belongs in `docs/harness-glossary.md` alongside the existing **unmeasurable
range** and **per-commit semantics** entries, not in `CONTEXT.md`. No ADR is
warranted for either unit — neither is hard to reverse,
and neither resolves a genuine trade-off that a future reader would puzzle
over.
